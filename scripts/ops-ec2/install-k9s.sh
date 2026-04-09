#!/usr/bin/env bash
set -euo pipefail

K9S_VERSION="${K9S_VERSION:-v0.50.18}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

log() {
  echo "[install-k9s] $1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "필수 명령어가 없습니다: $1"
    exit 1
  fi
}

detect_arch() {
  local arch
  arch="$(uname -m)"

  case "${arch}" in
    x86_64|amd64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      log "지원하지 않는 아키텍처입니다: ${arch}"
      exit 1
      ;;
  esac
}

main() {
  require_cmd curl
  require_cmd tar
  require_cmd sudo

  local arch
  arch="$(detect_arch)"

  local archive_name="k9s_Linux_${arch}.tar.gz"
  local download_url="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/${archive_name}"

  log "k9s 버전: ${K9S_VERSION}"
  log "아키텍처: ${arch}"
  log "다운로드 URL: ${download_url}"

  cd "${TMP_DIR}"
  curl -fL -o "${archive_name}" "${download_url}"
  tar -xzf "${archive_name}"

  if [[ ! -f k9s ]]; then
    log "압축 해제 후 k9s 바이너리를 찾지 못했습니다."
    exit 1
  fi

  chmod +x k9s
  sudo mv k9s "${INSTALL_DIR}/k9s"

  log "설치 완료: ${INSTALL_DIR}/k9s"
  "${INSTALL_DIR}/k9s" version
}

main "$@"