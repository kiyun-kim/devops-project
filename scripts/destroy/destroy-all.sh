#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/00-check.sh"
bash "${SCRIPT_DIR}/01-delete-argocd-apps.sh"
bash "${SCRIPT_DIR}/02-delete-app-namespaces.sh"
bash "${SCRIPT_DIR}/03-delete-platform-addons.sh"

echo
echo "중간 확인"
bash "${SCRIPT_DIR}/05-verify-empty.sh"

echo
echo "필요 시 finalizer 정리"
echo "bash ${SCRIPT_DIR}/04-clean-finalizers.sh"