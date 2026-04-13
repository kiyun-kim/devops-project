#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

MODE="${1:-final}"
status=0
terminating_status=0

print_list_or_ok() {
  local title="$1"
  local content="$2"

  echo
  echo "${title}"
  if [ -n "${content}" ]; then
    echo "${content}"
  else
    echo "없음"
  fi
}

verify_cluster_side() {
  local ingresses
  local lb_services
  local pvcs
  local pvs
  local karpenter_nodes
  local karpenter_nodepools=""
  local karpenter_nodeclasses=""
  local argocd_apps=""
  local argocd_appsets=""

  if ! kubectl cluster-info >/dev/null 2>&1; then
    echo
    echo "kubectl cluster 연결 불가 - cluster side 검증 생략"
    return 0
  fi

  echo
  echo "1. 전체 namespace 확인"
  kubectl get ns || true

  ingresses="$(list_ingresses)"
  lb_services="$(list_loadbalancer_services)"
  pvcs="$(list_pvcs)"
  pvs="$(list_pvs)"
  karpenter_nodes="$(list_karpenter_nodes)"

  if resource_type_available "nodepools.karpenter.sh"; then
    karpenter_nodepools="$(kubectl get nodepools.karpenter.sh -o name 2>/dev/null | sed 's#^nodepools.karpenter.sh/##')"
  fi

  if resource_type_available "ec2nodeclasses.karpenter.k8s.aws"; then
    karpenter_nodeclasses="$(kubectl get ec2nodeclasses.karpenter.k8s.aws -o name 2>/dev/null | sed 's#^ec2nodeclasses.karpenter.k8s.aws/##')"
  fi

  if namespace_exists "argocd" && resource_type_available "applications.argoproj.io"; then
    argocd_apps="$(kubectl get applications.argoproj.io -n argocd -o name 2>/dev/null | sed 's#^applications.argoproj.io/##')"
  fi

  if namespace_exists "argocd" && resource_type_available "applicationsets.argoproj.io"; then
    argocd_appsets="$(kubectl get applicationsets.argoproj.io -n argocd -o name 2>/dev/null | sed 's#^applicationsets.argoproj.io/##')"
  fi

  print_list_or_ok "2. ArgoCD Application 확인" "${argocd_apps}"
  print_list_or_ok "3. ArgoCD ApplicationSet 확인" "${argocd_appsets}"
  print_list_or_ok "4. ingress 확인" "${ingresses}"
  print_list_or_ok "5. LoadBalancer service 확인" "${lb_services}"
  print_list_or_ok "6. pvc 확인" "${pvcs}"
  print_list_or_ok "7. pv 확인" "${pvs}"
  print_list_or_ok "8. Karpenter node 확인" "${karpenter_nodes}"
  print_list_or_ok "9. Karpenter NodePool 확인" "${karpenter_nodepools}"
  print_list_or_ok "10. Karpenter EC2NodeClass 확인" "${karpenter_nodeclasses}"

  if [ -n "${pvcs}" ] || [ -n "${pvs}" ]; then
    terminating_status=2
  fi

  if [ -n "${argocd_apps}" ] || [ -n "${argocd_appsets}" ] || [ -n "${ingresses}" ] || [ -n "${lb_services}" ] || [ -n "${pvcs}" ] || [ -n "${pvs}" ] || [ -n "${karpenter_nodes}" ] || [ -n "${karpenter_nodepools}" ] || [ -n "${karpenter_nodeclasses}" ]; then
    status=1
  fi
}

verify_platform_state() {
  local platform_state

  platform_state="$(terraform_state_list_safe "${PLATFORM_DIR}" | grep -E 'helm_release\.karpenter|helm_release\.aws_load_balancer_controller|helm_release\.metrics_server|aws_sqs_queue\.karpenter_interruption|aws_cloudwatch_event_rule\.karpenter_|aws_cloudwatch_event_target\.karpenter_|aws_iam_role\.karpenter_|aws_iam_policy\.karpenter_controller|aws_eks_pod_identity_association\.karpenter|kubernetes_namespace_v1\.karpenter' || true)"
  print_list_or_ok "12. platform terraform state 잔여 리소스 확인" "${platform_state}"

  if [ -n "${platform_state}" ]; then
    status=1
  fi
}

verify_infra_state() {
  local infra_state

  infra_state="$(terraform_state_list_safe "${INFRA_DIR}" | grep -E '^module\.eks($|[.])|^module\.ops_ec2($|[.])|^aws_eks_pod_identity_association\.alb_controller$|^aws_iam_role_policy_attachment\.alb_controller$|^aws_iam_role\.alb_controller_pod_identity$|^aws_iam_policy\.alb_controller$' || true)"
  print_list_or_ok "13. infra terraform state 잔여 리소스 확인" "${infra_state}"

  if [ -n "${infra_state}" ]; then
    status=1
  fi
}

verify_aws_side() {
  local ec2_instances
  local nodegroups=""

  echo
  echo "14. AWS EKS cluster 확인"
  if aws_eks_cluster_exists; then
    echo "cluster 남아 있음: ${CLUSTER_NAME}"
    status=1

    nodegroups="$(aws eks list-nodegroups \
      --region "${AWS_REGION}" \
      --cluster-name "${CLUSTER_NAME}" \
      --query 'nodegroups[]' \
      --output text 2>/dev/null || true)"
  else
    echo "cluster 없음"
  fi

  print_list_or_ok "15. EKS managed node group 확인" "${nodegroups}"
  if [ -n "${nodegroups}" ]; then
    status=1
  fi

  ec2_instances="$(aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=tag:Project,Values=${PROJECT_TAG}" "Name=tag:Environment,Values=${ENVIRONMENT_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Name:Tags[?Key==`Name`]|[0].Value}' \
    --output json 2>/dev/null \
      | jq -r '.[] | "\(.InstanceId)\t\(.State)\t\(.Name // "-")"' || true)"

  print_list_or_ok "16. EC2 인스턴스 확인" "${ec2_instances}"
  if [ -n "${ec2_instances}" ]; then
    status=1
  fi
}

log_section "[04] destroy 결과 검증 (${MODE})"

if [ "${MODE}" = "pre-terraform" ]; then
  verify_cluster_side

  if [ "${terminating_status}" -eq 2 ]; then
    exit 2
  fi

  exit "${status}"
fi

verify_cluster_side
verify_platform_state
verify_infra_state
verify_aws_side

if [ "${terminating_status}" -eq 2 ]; then
  exit 2
fi

exit "${status}"
