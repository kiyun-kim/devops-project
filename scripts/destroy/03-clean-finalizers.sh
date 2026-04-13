#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_section "[03] namespace finalizer 정리"

clean_pvc_finalizers() {
  local ns="$1"
  local pvc_name

  if ! namespace_exists "${ns}"; then
    return 0
  fi

  while IFS= read -r pvc_name; do
    [ -n "${pvc_name}" ] || continue
    echo "PVC finalizer 제거: ${ns}/${pvc_name}"
    kubectl patch pvc "${pvc_name}" \
      -n "${ns}" \
      --type=merge \
      -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  done < <(list_pvc_names_in_namespace "${ns}")
}

clean_ingress_finalizers() {
  local ns="$1"
  local ingress_name

  if ! namespace_exists "${ns}"; then
    return 0
  fi

  while IFS= read -r ingress_name; do
    [ -n "${ingress_name}" ] || continue
    echo "Ingress finalizer 제거: ${ns}/${ingress_name}"
    kubectl patch ingress "${ingress_name}" \
      -n "${ns}" \
      --type=merge \
      -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
    kubectl delete ingress "${ingress_name}" \
      -n "${ns}" \
      --ignore-not-found=true \
      --wait=false \
      --timeout=30s || true
  done < <(list_ingress_names_in_namespace "${ns}")
}

clean_pv_finalizers() {
  local pv_name

  while IFS= read -r pv_name; do
    [ -n "${pv_name}" ] || continue
    echo "PV finalizer 제거: ${pv_name}"
    kubectl patch pv "${pv_name}" \
      --type=merge \
      -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  done < <(list_pvs)
}

while IFS= read -r ingress_ref; do
  [ -n "${ingress_ref}" ] || continue
  log_step "finalizer" "ingress ${ingress_ref}"
  clean_ingress_finalizers "${ingress_ref%%/*}"
done < <(list_ingresses)

for ns in "${STATEFUL_NAMESPACES[@]}"; do
  log_step "finalizer" "pvc ${ns}"
  clean_pvc_finalizers "${ns}"
done

log_step "finalizer" "pv"
clean_pv_finalizers

echo "03-clean-finalizers.sh 완료"
