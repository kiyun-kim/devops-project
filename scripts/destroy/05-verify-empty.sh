#!/usr/bin/env bash
set -euo pipefail

echo "1. 전체 namespace 확인"
kubectl get ns

echo
echo "2. ingress 확인"
kubectl get ingress -A || true

echo
echo "3. service 확인"
kubectl get svc -A || true

echo
echo "4. pvc 확인"
kubectl get pvc -A || true

echo
echo "5. karpenter node 확인"
kubectl get node || true