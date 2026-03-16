#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-northeast-2}"
CLUSTER_NAME="${1:-dev-eks-v2}"

echo "Updating kubeconfig for cluster: ${CLUSTER_NAME}"
aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$CLUSTER_NAME"

echo
echo "Current context:"
kubectl config current-context
echo
kubectl get nodes -o wide