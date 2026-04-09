#!/usr/bin/env bash
set -euo pipefail

KUBECOLOR_REPO_URL="${KUBECOLOR_REPO_URL:-https://kubecolor.github.io/packages/rpm/kubecolor.repo}"
PROFILE_SCRIPT="${PROFILE_SCRIPT:-/etc/profile.d/zz-kubecolor.sh}"

log() {
  echo "[install-kubecolor] $1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "필수 명령어가 없습니다: $1"
    exit 1
  fi
}

detect_dnf_major_version() {
  local version

  version="$(dnf --version 2>/dev/null | head -n 1 | awk '{print $1}')"
  version="${version%%.*}"

  if [[ -z "${version}" ]]; then
    log "dnf 버전을 확인하지 못했습니다."
    exit 1
  fi

  echo "${version}"
}

install_repo() {
  local dnf_major_version="$1"

  if [[ "${dnf_major_version}" -ge 5 ]]; then
    sudo dnf install -y dnf5-plugins
    sudo dnf config-manager addrepo --from-repofile "${KUBECOLOR_REPO_URL}"
    return
  fi

  sudo dnf install -y 'dnf-command(config-manager)'
  sudo dnf config-manager --add-repo "${KUBECOLOR_REPO_URL}"
}

write_profile_script() {
  sudo tee "${PROFILE_SCRIPT}" >/dev/null <<'SCRIPT'
export KUBECOLOR_FORCE_COLORS=auto
alias kubectl=kubecolor
alias k=kubectl

if [ -n "${BASH_VERSION:-}" ] && declare -F __start_kubectl >/dev/null 2>&1; then
  complete -o default -F __start_kubectl kubecolor
  complete -o default -F __start_kubectl k
fi

if [ -n "${ZSH_VERSION:-}" ] && command -v compdef >/dev/null 2>&1; then
  compdef kubecolor=kubectl
  compdef k=kubectl
fi
SCRIPT

  sudo chmod 644 "${PROFILE_SCRIPT}"
}

main() {
  require_cmd dnf
  require_cmd sudo
  require_cmd tee
  require_cmd awk
  require_cmd head

  if ! command -v kubectl >/dev/null 2>&1; then
    log "kubectl이 먼저 설치되어 있어야 합니다."
    exit 1
  fi

  local dnf_major_version
  dnf_major_version="$(detect_dnf_major_version)"

  log "dnf 메이저 버전: ${dnf_major_version}"
  log "kubecolor 저장소 설정"
  install_repo "${dnf_major_version}"

  log "kubecolor 설치"
  sudo dnf install -y kubecolor

  log "kubecolor shell alias 설정"
  write_profile_script

  log "설치 완료"
  kubecolor --kubecolor-version
  log "새 셸을 열거나 'source ${PROFILE_SCRIPT}' 후 'k get pods' 형태로 사용할 수 있습니다."
}

main "$@"
