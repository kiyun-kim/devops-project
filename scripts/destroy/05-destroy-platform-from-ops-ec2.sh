#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_section "[05] Terraform platform destroy"
terraform_init "${PLATFORM_DIR}"

log_step "destroy" "platform 전체 destroy"
terraform -chdir="${PLATFORM_DIR}" destroy -auto-approve -input=false

echo
echo "05-destroy-platform-from-ops-ec2.sh 완료"
