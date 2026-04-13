#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_section "[03] namespace finalizer 정리"

clean_pv_finalizers() {
  kubectl get pv -o json 2>/dev/null \
    | jq '.items[].metadata.finalizers = []' 2>/dev/null \
    | kubectl apply -f - >/dev/null 2>&1 || true
}

log_step "finalizer" "pv"
clean_pv_finalizers

echo "03-clean-finalizers.sh 완료"
