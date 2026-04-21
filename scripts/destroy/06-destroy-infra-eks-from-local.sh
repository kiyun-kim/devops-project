#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_section "[06] Terraform infra EKS destroy"
terraform_init "${INFRA_DIR}"

log_step "destroy" "EKS 및 ALB controller pod identity 관련 리소스 삭제"
terraform -chdir="${INFRA_DIR}" destroy -auto-approve -input=false \
  -target=module.eks \
  -target=aws_eks_pod_identity_association.alb_controller \
  -target=aws_iam_role_policy_attachment.alb_controller \
  -target=aws_iam_role.alb_controller_pod_identity \
  -target=aws_iam_policy.alb_controller

echo
echo "06-destroy-infra-eks-from-local.sh 완료"
