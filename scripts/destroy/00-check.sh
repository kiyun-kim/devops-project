#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] kubectl context 확인"
kubectl config current-context

echo
echo "[2/4] cluster 연결 확인"
kubectl cluster-info

echo
echo "[3/4] namespace 목록"
kubectl get ns

echo
echo "[4/4] ingress / svc / pvc 확인"
kubectl get ingress -A || true
kubectl get svc -A || true
kubectl get pvc -A || true

echo
echo "사전 확인 완료"