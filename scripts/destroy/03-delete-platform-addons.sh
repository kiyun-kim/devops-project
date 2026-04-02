#!/usr/bin/env bash
set -euo pipefail

echo "1. Karpenter CR 삭제"
kubectl delete nodepool --all || true
kubectl delete ec2nodeclass --all || true

echo
echo "2. Karpenter namespace 리소스 삭제"
kubectl delete all --all -n karpenter --timeout=180s || true
kubectl delete ns karpenter --timeout=180s || true

echo
echo "3. KEDA namespace 리소스 삭제"
kubectl delete scaledobject --all -A || true
kubectl delete triggerauthentication --all -A || true
kubectl delete all --all -n keda --timeout=180s || true
kubectl delete ns keda --timeout=180s || true

echo
echo "4. ArgoCD namespace 삭제"
kubectl delete all --all -n argocd --timeout=180s || true
kubectl delete ns argocd --timeout=180s || true

echo
echo "5. kube-system 내 AWS LB Controller 확인"
kubectl get deploy -n kube-system | grep -E 'aws-load-balancer-controller|external-dns|metrics-server' || true