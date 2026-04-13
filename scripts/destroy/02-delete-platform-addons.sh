#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

wait_for_karpenter_nodes() {
  local attempts=18
  local sleep_seconds=10
  local i
  local remaining

  for ((i = 1; i <= attempts; i++)); do
    remaining="$(list_karpenter_nodes)"
    if [ -z "${remaining}" ]; then
      echo "Karpenter node 없음"
      return 0
    fi

    echo "남아 있는 Karpenter node:"
    echo "${remaining}"
    sleep "${sleep_seconds}"
  done

  return 1
}

cleanup_stale_karpenter_nodes() {
  local node_name
  local provider_id
  local instance_id
  local instance_state

  while IFS=$'\t' read -r node_name provider_id; do
    [ -n "${node_name}" ] || continue

    instance_id="${provider_id##*/}"
    if [ -z "${instance_id}" ] || [ "${instance_id}" = "${provider_id}" ]; then
      continue
    fi

    instance_state="$(aws ec2 describe-instances \
      --region "${AWS_REGION}" \
      --instance-ids "${instance_id}" \
      --query 'Reservations[0].Instances[0].State.Name' \
      --output text 2>/dev/null || true)"

    if [ -z "${instance_state}" ] || [ "${instance_state}" = "None" ] || [ "${instance_state}" = "terminated" ] || [ "${instance_state}" = "shutting-down" ]; then
      echo "stale karpenter node 정리: ${node_name} (${instance_id:-unknown})"
      kubectl delete node "${node_name}" --ignore-not-found=true --wait=false --timeout=30s || true
    fi
  done < <(list_karpenter_node_provider_pairs)
}

log_section "[02] platform addon 정리"

log_step "1/5" "Karpenter CR 삭제"
if resource_type_available "nodepools.karpenter.sh"; then
  kubectl delete nodepools.karpenter.sh --all --ignore-not-found=true --wait=false --timeout=30s || true
else
  echo "nodepools.karpenter.sh 없음"
fi

if resource_type_available "ec2nodeclasses.karpenter.k8s.aws"; then
  kubectl delete ec2nodeclasses.karpenter.k8s.aws --all --ignore-not-found=true --wait=false --timeout=30s || true
else
  echo "ec2nodeclasses.karpenter.k8s.aws 없음"
fi

log_step "2/5" "KEDA CR 삭제"
if resource_type_available "scaledobjects.keda.sh"; then
  kubectl delete scaledobjects.keda.sh --all -A --ignore-not-found=true --wait=false --timeout=30s || true
else
  echo "scaledobjects.keda.sh 없음"
fi

if resource_type_available "triggerauthentications.keda.sh"; then
  kubectl delete triggerauthentications.keda.sh --all -A --ignore-not-found=true --wait=false --timeout=30s || true
else
  echo "triggerauthentications.keda.sh 없음"
fi

log_step "3/5" "Karpenter node 감소 대기"
cleanup_stale_karpenter_nodes
wait_for_karpenter_nodes || true

log_step "4/5" "platform namespace 상태 확인"
kubectl get ns argocd keda karpenter 2>/dev/null || true

log_step "5/5" "kube-system 내 AWS LB Controller 확인"
kubectl get deploy -n kube-system | grep -E 'aws-load-balancer-controller|external-dns|metrics-server' || true

echo
echo "02-delete-platform-addons.sh 완료"
