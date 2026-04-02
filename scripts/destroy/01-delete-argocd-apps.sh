#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NS="argocd"

echo "[1] ArgoCD Applications 삭제"
kubectl get applications.argoproj.io -n ${ARGOCD_NS} || true

kubectl delete applications.argoproj.io --all -n ${ARGOCD_NS} --wait=true || true

echo
echo "[2] 삭제 대기"
sleep 15

echo
echo "[3] 남은 Application 확인"
kubectl get applications.argoproj.io -n ${ARGOCD_NS} || true
