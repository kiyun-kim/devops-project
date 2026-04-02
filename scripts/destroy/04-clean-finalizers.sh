#!/usr/bin/env bash
set -euo pipefail

TARGET_NAMESPACES=(
  truve-kafka
  truve-redis
  kubecost
  observability
  keda
  karpenter
  argocd
)

for ns in "${TARGET_NAMESPACES[@]}"; do
  echo "=================================================="
  echo "finalizer 정리: ${ns}"
  echo "=================================================="

  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    kubectl get namespace "${ns}" -o json \
      | jq '.spec.finalizers = []' \
      | kubectl replace --raw "/api/v1/namespaces/${ns}/finalize" -f - || true
  else
    echo "namespace 없음: ${ns}"
  fi

  echo
done