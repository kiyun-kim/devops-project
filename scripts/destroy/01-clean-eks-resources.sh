#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

cleanup_argocd_apps() {
  local argocd_ns="argocd"

  log_step "1" "ArgoCD Application / ApplicationSet 정리"
  if ! namespace_exists "${argocd_ns}"; then
    echo "namespace ${argocd_ns} 없음 - 스킵"
    return 0
  fi

  if resource_type_available "applicationsets.argoproj.io"; then
    kubectl get applicationsets.argoproj.io -n "${argocd_ns}" || true
    kubectl delete applicationsets.argoproj.io --all \
      -n "${argocd_ns}" \
      --ignore-not-found=true \
      --wait=true \
      --timeout=180s || true
  else
    echo "applicationsets.argoproj.io 리소스 타입 없음"
  fi

  if resource_type_available "applications.argoproj.io"; then
    kubectl get applications.argoproj.io -n "${argocd_ns}" || true
    kubectl delete applications.argoproj.io --all \
      -n "${argocd_ns}" \
      --ignore-not-found=true \
      --wait=true \
      --timeout=180s || true
  else
    echo "applications.argoproj.io 리소스 타입 없음"
  fi

  sleep 30
}

delete_namespace_ingresses() {
  local ns="$1"
  local ingresses
  local resource

  if ! namespace_exists "${ns}"; then
    return 0
  fi

  ingresses="$(kubectl get ingress -n "${ns}" -o json 2>/dev/null \
    | jq -r '.items[]?.metadata.name')"
  if [ -n "${ingresses:-}" ]; then
    log_step "2" "Ingress 삭제: ${ns}"
    for resource in ${ingresses}; do
      kubectl delete ingress "${resource}" -n "${ns}" --ignore-not-found=true --timeout=180s || true
    done
  fi
}

delete_loadbalancer_services() {
  local ns
  local lb_services
  local resource

  while IFS= read -r ns; do
    [ -n "${ns}" ] || continue
    lb_services="$(kubectl get svc -n "${ns}" -o json 2>/dev/null \
      | jq -r '.items[]
        | select(.spec.type == "LoadBalancer")
        | .metadata.name')"
    if [ -n "${lb_services:-}" ]; then
      log_step "3" "LoadBalancer Service 삭제: ${ns}"
      for resource in ${lb_services}; do
        kubectl delete svc "${resource}" -n "${ns}" --ignore-not-found=true --timeout=180s || true
      done
    fi
  done < <(list_non_system_namespaces || true)
}

delete_stateful_pvcs() {
  local ns
  local pvc_name

  for ns in "${STATEFUL_NAMESPACES[@]}"; do
    if namespace_exists "${ns}"; then
      log_step "4" "PVC 삭제: ${ns}"
      kubectl get pvc -n "${ns}" || true
      while IFS= read -r pvc_name; do
        [ -n "${pvc_name}" ] || continue
        kubectl delete pvc "${pvc_name}" \
          -n "${ns}" \
          --ignore-not-found=true \
          --wait=false \
          --timeout=5s || true
      done < <(list_pvc_names_in_namespace "${ns}")
    fi
  done
}

log_section "[01] EKS 내부 리소스 정리"
cleanup_argocd_apps

delete_loadbalancer_services
delete_stateful_pvcs

log_step "2" "모든 namespace의 Ingress 삭제"
while IFS= read -r ns; do
  [ -n "${ns}" ] || continue
  delete_namespace_ingresses "${ns}"
done < <(list_non_system_namespaces || true)

log_step "5" "리소스 정리 반영 대기"
sleep 20

echo "01-clean-eks-resources.sh 완료"
