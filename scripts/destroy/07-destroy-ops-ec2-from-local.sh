#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_section "[07] Terraform ops-ec2 destroy"
terraform_init "${INFRA_DIR}"

log_step "destroy" "ops EC2 삭제"
terraform -chdir="${INFRA_DIR}" destroy -auto-approve -input=false \
  -target=module.ops_ec2

echo
echo "07-destroy-ops-ec2-from-local.sh 완료"
