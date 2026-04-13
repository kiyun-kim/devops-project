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

run_step "[1/5] 사전 검증" "00-check.sh"
run_step "[2/5] EKS 삭제 전 필수 리소스 정리" "01-clean-eks-resources.sh"
run_step "[3/5] platform addon 정리" "02-delete-platform-addons.sh"

log_section "[4/5] EKS 삭제 전 필수 리소스 검증"
set +e
bash "${SCRIPT_DIR}/04-verify-pre-platform-destroy.sh"
verify_status=$?
set -e

if [ "${verify_status}" -eq 2 ]; then
  echo "PVC/PV 잔여물 발견 - PV finalizer 정리 진행"
  bash "${SCRIPT_DIR}/03-clean-finalizers.sh"
  set +e
  bash "${SCRIPT_DIR}/04-verify-pre-platform-destroy.sh"
  verify_status=$?
  set -e
  if [ "${verify_status}" -ne 0 ]; then
    echo "PV/PVC finalizer 정리 후에도 필수 리소스가 남아 있습니다." >&2
    exit "${verify_status}"
  fi
elif [ "${verify_status}" -ne 0 ]; then
  echo "EKS destroy 전에 정리해야 할 필수 리소스가 남아 있습니다." >&2
  exit "${verify_status}"
fi

run_step "[5/5] platform terraform destroy" "05-destroy-platform-from-ops-ec2.sh"

echo
echo "ops-ec2 단계 완료"
echo "다음은 로컬 터미널에서 infra 기준 EKS / ops-ec2 destroy를 진행하세요."
echo "  bash ${SCRIPT_DIR}/run-from-local.sh"
