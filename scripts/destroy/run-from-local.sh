#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

run_step() {
  local label="$1"
  local script_name="$2"

  log_section "${label}"
  bash "${SCRIPT_DIR}/${script_name}"
}

log_section "[로컬 1/4] AWS 자격 증명 및 Terraform 환경 확인"
require_command terraform
require_command aws
aws sts get-caller-identity
ensure_directory "${INFRA_DIR}"

run_step "[로컬 2/4] infra EKS destroy" "06-destroy-infra-eks-from-local.sh"
run_step "[로컬 3/4] ops-ec2 destroy" "07-destroy-ops-ec2-from-local.sh"

log_section "[로컬 4/4] 최종 비용 리소스 검증"
bash "${SCRIPT_DIR}/08-verify-final-state.sh"

echo
echo "run-from-local.sh 완료"
