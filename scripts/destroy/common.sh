#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRUVE_TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_NAME="dev"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
CLUSTER_NAME="${CLUSTER_NAME:-truve-eks-dev}"
PROJECT_TAG="${PROJECT_TAG:-truve}"
ENVIRONMENT_TAG="${ENVIRONMENT_TAG:-dev}"

PLATFORM_DIR="${TRUVE_TERRAFORM_DIR}/envs/${ENV_NAME}/platform"
INFRA_DIR="${TRUVE_TERRAFORM_DIR}/envs/${ENV_NAME}/infra"

STATEFUL_NAMESPACES=(
  truve-kafka
  truve-redis
)

PLATFORM_NAMESPACES=(
  argocd
  keda
  karpenter
)

SYSTEM_NAMESPACES=(
  default
  kube-node-lease
  kube-public
  kube-system
)

log_section() {
  echo
  echo "=================================================="
  echo "$1"
  echo "=================================================="
}

log_step() {
  echo
  echo "[$1] $2"
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "필수 명령어 없음: ${cmd}" >&2
    return 1
  fi
}

ensure_directory() {
  local dir="$1"
  if [ ! -d "${dir}" ]; then
    echo "필수 디렉터리 없음: ${dir}" >&2
    return 1
  fi
}

namespace_exists() {
  local ns="$1"
  kubectl get namespace "${ns}" >/dev/null 2>&1
}

resource_type_available() {
  local resource_name="$1"
  kubectl api-resources -o name 2>/dev/null | grep -qx "${resource_name}"
}

list_terminating_namespaces() {
  kubectl get namespaces -o json 2>/dev/null \
    | jq -r '.items[]
      | select(.status.phase == "Terminating")
      | .metadata.name'
}

wait_for_namespace_deletion() {
  local ns="$1"
  local attempts="${2:-18}"
  local sleep_seconds="${3:-10}"
  local i

  for ((i = 1; i <= attempts; i++)); do
    if ! namespace_exists "${ns}"; then
      return 0
    fi
    sleep "${sleep_seconds}"
  done

  return 1
}

terraform_init() {
  local dir="$1"
  log_step "terraform" "init: ${dir}"
  terraform -chdir="${dir}" init -input=false
}

terraform_state_list_safe() {
  local dir="$1"

  if [ ! -d "${dir}" ]; then
    return 0
  fi

  terraform -chdir="${dir}" init -input=false >/dev/null 2>&1 || return 0
  terraform -chdir="${dir}" state list 2>/dev/null || true
}

aws_eks_cluster_exists() {
  aws eks describe-cluster \
    --region "${AWS_REGION}" \
    --name "${CLUSTER_NAME}" >/dev/null 2>&1
}

list_non_system_namespaces() {
  kubectl get namespaces -o json 2>/dev/null \
    | jq -r --argjson system "$(printf '%s\n' "${SYSTEM_NAMESPACES[@]}" | jq -R . | jq -s .)" '
        .items[]
        | .metadata.name as $name
        | select(($system | index($name)) | not)
        | $name'
}

list_loadbalancer_services() {
  kubectl get svc -A -o json 2>/dev/null \
    | jq -r '.items[]
      | select(.spec.type == "LoadBalancer")
      | "\(.metadata.namespace)/\(.metadata.name)"'
}

list_ingresses() {
  kubectl get ingress -A -o json 2>/dev/null \
    | jq -r '.items[]
      | "\(.metadata.namespace)/\(.metadata.name)"'
}

list_ingress_names_in_namespace() {
  local ns="$1"

  kubectl get ingress -n "${ns}" -o json 2>/dev/null \
    | jq -r '.items[]?.metadata.name'
}

list_pvcs() {
  kubectl get pvc -A -o json 2>/dev/null \
    | jq -r '.items[]
      | "\(.metadata.namespace)/\(.metadata.name)"'
}

list_pvs() {
  kubectl get pv -o json 2>/dev/null \
    | jq -r '.items[]
      | .metadata.name'
}

list_pvc_names_in_namespace() {
  local ns="$1"

  kubectl get pvc -n "${ns}" -o json 2>/dev/null \
    | jq -r '.items[]?.metadata.name'
}

list_karpenter_nodes() {
  kubectl get nodes -l karpenter.sh/nodepool -o name 2>/dev/null \
    | sed 's#^node/##'
}

list_karpenter_node_provider_pairs() {
  kubectl get nodes -l karpenter.sh/nodepool -o json 2>/dev/null \
    | jq -r '.items[]
      | "\(.metadata.name)\t\(.spec.providerID // "")"'
}

list_ready_nodes() {
  kubectl get nodes --no-headers 2>/dev/null \
    | awk '$2 ~ /Ready/ {print $1}'
}
