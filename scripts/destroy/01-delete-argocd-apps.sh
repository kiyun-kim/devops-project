#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NS="argocd"

echo "=================================================="
echo "[1] ArgoCD namespace 존재 여부 확인"
echo "=================================================="
if ! kubectl get ns "${ARGOCD_NS}" >/dev/null 2>&1; then
  echo "namespace ${ARGOCD_NS} 없음 - 스킵"
  exit 0
fi

echo
echo "=================================================="
echo "[2] 삭제 전 ArgoCD Application / ApplicationSet 확인"
echo "=================================================="
kubectl get applications.argoproj.io -n "${ARGOCD_NS}" || true
kubectl get applicationsets.argoproj.io -n "${ARGOCD_NS}" || true

echo
echo "=================================================="
echo "[3] ArgoCD Application 삭제"
echo "=================================================="
kubectl delete applications.argoproj.io --all -n "${ARGOCD_NS}" --wait=true || true

echo
echo "=================================================="
echo "[4] ArgoCD ApplicationSet 삭제"
echo "=================================================="
kubectl delete applicationsets.argoproj.io --all -n "${ARGOCD_NS}" --wait=true || true

echo
echo "=================================================="
echo "[5] 삭제 반영 대기"
echo "=================================================="
sleep 20

echo
echo "=================================================="
echo "[6] 삭제 후 ArgoCD Application / ApplicationSet 확인"
echo "=================================================="
kubectl get applications.argoproj.io -n "${ARGOCD_NS}" || true
kubectl get applicationsets.argoproj.io -n "${ARGOCD_NS}" || true

echo
echo "01-delete-argocd-apps.sh 완료"