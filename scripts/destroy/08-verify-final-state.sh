#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

status=0

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

verify_platform_state() {
  local platform_state

  platform_state="$(terraform_state_list_safe "${PLATFORM_DIR}" | grep -E 'helm_release\.karpenter|helm_release\.aws_load_balancer_controller|helm_release\.metrics_server|aws_sqs_queue\.karpenter_interruption|aws_cloudwatch_event_rule\.karpenter_|aws_cloudwatch_event_target\.karpenter_|aws_iam_role\.karpenter_|aws_iam_policy\.karpenter_controller|aws_eks_pod_identity_association\.karpenter|kubernetes_namespace_v1\.karpenter' || true)"
  print_list_or_ok "1. platform terraform state 잔여 리소스 확인" "${platform_state}"

  if [ -n "${platform_state}" ]; then
    status=1
  fi
}

verify_infra_state() {
  local infra_state

  infra_state="$(terraform_state_list_safe "${INFRA_DIR}" | grep -E '^module\.eks($|[.])|^module\.ops_ec2($|[.])|^aws_eks_pod_identity_association\.alb_controller$|^aws_iam_role_policy_attachment\.alb_controller$|^aws_iam_role\.alb_controller_pod_identity$|^aws_iam_policy\.alb_controller$' || true)"
  print_list_or_ok "2. infra terraform state 잔여 리소스 확인" "${infra_state}"

  if [ -n "${infra_state}" ]; then
    status=1
  fi
}

verify_aws_side() {
  local ec2_instances
  local nodegroups=""

  echo
  echo "3. AWS EKS cluster 확인"
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

  print_list_or_ok "4. EKS managed node group 확인" "${nodegroups}"
  if [ -n "${nodegroups}" ]; then
    status=1
  fi

  ec2_instances="$(aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=tag:Project,Values=${PROJECT_TAG}" "Name=tag:Environment,Values=${ENVIRONMENT_TAG}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Name:Tags[?Key==`Name`]|[0].Value}' \
    --output json 2>/dev/null \
      | jq -r '.[] | "\(.InstanceId)\t\(.State)\t\(.Name // "-")"' || true)"

  print_list_or_ok "5. EC2 인스턴스 확인" "${ec2_instances}"
  if [ -n "${ec2_instances}" ]; then
    status=1
  fi
}

main() {
  log_section "[08] 최종 비용 리소스 검증"
  verify_platform_state
  verify_infra_state
  verify_aws_side
  exit "${status}"
}

main "$@"
