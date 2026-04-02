#!/usr/bin/env bash
set -euo pipefail

NAMESPACES=(
  truve-auth-service
  truve-gateway-service
  truve-musical-service
  truve-payment-service
  truve-queue-service
  truve-ticketing-service
  truve-kafka
  truve-redis
  kubecost
  observability
)

for ns in "${NAMESPACES[@]}"; do
  echo "=================================================="
  echo "namespace 삭제 시작: ${ns}"
  echo "=================================================="

  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    echo "1. ingress 삭제"
    kubectl delete ingress --all -n "${ns}" --timeout=120s || true

    echo "2. LoadBalancer 서비스 삭제"
    kubectl delete svc --all -n "${ns}" --timeout=120s || true

    echo "3. PVC 삭제"
    kubectl delete pvc --all -n "${ns}" --timeout=120s || true

    echo "4. 전체 workload 삭제"
    kubectl delete all --all -n "${ns}" --timeout=180s || true

    echo "5. namespace 삭제"
    kubectl delete ns "${ns}" --timeout=180s || true
  else
    echo "namespace 없음: ${ns}"
  fi

  echo
done