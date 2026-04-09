#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${PROJECT_ROOT}/envs/dev/infra"

echo "[1/3] Move to infra directory"
cd "${INFRA_DIR}"

echo "[2/3] Terraform init"
terraform init

echo "[3/3] Replace ops-ec2 instance only"
terraform apply -replace=module.ops_ec2.aws_instance.this -auto-approve

echo
echo "Done. Reconnect to ops-ec2 and verify:"
echo "  ./scripts/connect-ops.sh"
echo "  cloud-init status"
echo "  ls -l /usr/local/bin/setup-kubeconfig"
