#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

status=0
needs_pv_cleanup=0

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

main() {
  local ingresses
  local lb_services
  local pvcs
  local pvs
  local karpenter_nodes
  local karpenter_nodepools=""
  local karpenter_nodeclasses=""
  local argocd_apps=""
  local argocd_appsets=""

  log_section "[04] platform destroy 전 검증"

  if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "kubectl cluster 연결 불가 - precheck 실패" >&2
    exit 1
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
    needs_pv_cleanup=1
    status=1
  fi

  if [ -n "${argocd_apps}" ] || [ -n "${argocd_appsets}" ] || [ -n "${ingresses}" ] || [ -n "${lb_services}" ] || [ -n "${karpenter_nodes}" ] || [ -n "${karpenter_nodepools}" ] || [ -n "${karpenter_nodeclasses}" ]; then
    status=1
  fi

  if [ "${needs_pv_cleanup}" -eq 1 ]; then
    exit 2
  fi

  exit "${status}"
}

main "$@"
