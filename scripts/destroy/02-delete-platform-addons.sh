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

delete_namespace_bundle() {
  local ns="$1"

  if ! namespace_exists "${ns}"; then
    echo "namespace 없음: ${ns}"
    return 0
  fi

  kubectl delete deployment --all -n "${ns}" --ignore-not-found=true --timeout=180s || true
  kubectl delete statefulset --all -n "${ns}" --ignore-not-found=true --timeout=180s || true
  kubectl delete daemonset --all -n "${ns}" --ignore-not-found=true --timeout=180s || true
  kubectl delete ingress --all -n "${ns}" --ignore-not-found=true --timeout=180s || true
  kubectl delete service --all -n "${ns}" --ignore-not-found=true --timeout=180s || true
  kubectl delete serviceaccount --all -n "${ns}" --ignore-not-found=true --timeout=120s || true
  kubectl delete configmap --all -n "${ns}" --ignore-not-found=true --timeout=120s || true
  kubectl delete secret --all -n "${ns}" --ignore-not-found=true --timeout=120s || true
}

log_section "[02] platform addon 정리"

log_step "1/5" "Karpenter CR 삭제"
if resource_type_available "nodepools.karpenter.sh"; then
  kubectl delete nodepools.karpenter.sh --all --ignore-not-found=true --timeout=180s || true
else
  echo "nodepools.karpenter.sh 없음"
fi

if resource_type_available "ec2nodeclasses.karpenter.k8s.aws"; then
  kubectl delete ec2nodeclasses.karpenter.k8s.aws --all --ignore-not-found=true --timeout=180s || true
else
  echo "ec2nodeclasses.karpenter.k8s.aws 없음"
fi

log_step "2/5" "KEDA CR 삭제"
if resource_type_available "scaledobjects.keda.sh"; then
  kubectl delete scaledobjects.keda.sh --all -A --ignore-not-found=true --timeout=180s || true
else
  echo "scaledobjects.keda.sh 없음"
fi

if resource_type_available "triggerauthentications.keda.sh"; then
  kubectl delete triggerauthentications.keda.sh --all -A --ignore-not-found=true --timeout=180s || true
else
  echo "triggerauthentications.keda.sh 없음"
fi

log_step "3/5" "Karpenter namespace workload 삭제"
delete_namespace_bundle "karpenter"
echo "Karpenter node 감소 대기"
wait_for_karpenter_nodes || true

log_step "4/5" "argocd / keda / karpenter namespace 삭제"
delete_namespace_bundle "argocd"
delete_namespace_bundle "keda"
delete_namespace_bundle "karpenter"

log_step "5/5" "kube-system 내 AWS LB Controller 확인"
kubectl get deploy -n kube-system | grep -E 'aws-load-balancer-controller|external-dns|metrics-server' || true

echo
echo "02-delete-platform-addons.sh 완료"
