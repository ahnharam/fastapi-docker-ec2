#!/usr/bin/env bash
set -Eeuo pipefail

readonly DEFAULT_COMPOSE_VERSION="v5.3.1"
COMPOSE_DOWNLOAD_DIR=""

cleanup() {
  if [[ -n "${COMPOSE_DOWNLOAD_DIR}" && -d "${COMPOSE_DOWNLOAD_DIR}" ]]; then
    rm -rf -- "${COMPOSE_DOWNLOAD_DIR}"
  fi
}

trap cleanup EXIT

fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail "Root privileges are required and sudo is unavailable."
  fi
}

docker_cmd() {
  as_root docker "$@"
}

install_compose_plugin() {
  local compose_version="${COMPOSE_VERSION:-${DEFAULT_COMPOSE_VERSION}}"
  local machine_arch
  local release_arch
  local asset_name
  local release_base
  local temporary_dir
  local downloaded_binary
  local downloaded_checksum
  local expected_checksum
  local actual_checksum

  [[ "${compose_version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || fail "COMPOSE_VERSION must look like v5.3.1."

  machine_arch="$(uname -m)"
  case "${machine_arch}" in
    x86_64|amd64) release_arch="x86_64" ;;
    aarch64|arm64) release_arch="aarch64" ;;
    *) fail "Unsupported CPU architecture for Docker Compose: ${machine_arch}" ;;
  esac

  asset_name="docker-compose-linux-${release_arch}"
  release_base="https://github.com/docker/compose/releases/download/${compose_version}"
  temporary_dir="$(mktemp -d)"
  COMPOSE_DOWNLOAD_DIR="${temporary_dir}"
  downloaded_binary="${temporary_dir}/${asset_name}"
  downloaded_checksum="${temporary_dir}/${asset_name}.sha256"

  echo "[BOOTSTRAP] Docker Compose is missing; installing official ${compose_version} plugin"
  curl --fail --show-error --silent --location \
    --proto '=https' --tlsv1.2 \
    "${release_base}/${asset_name}" \
    --output "${downloaded_binary}"
  curl --fail --show-error --silent --location \
    --proto '=https' --tlsv1.2 \
    "${release_base}/${asset_name}.sha256" \
    --output "${downloaded_checksum}"

  expected_checksum="$(awk 'NR == 1 {print $1}' "${downloaded_checksum}")"
  actual_checksum="$(sha256sum "${downloaded_binary}" | awk '{print $1}')"
  [[ "${expected_checksum}" =~ ^[0-9a-fA-F]{64}$ ]] \
    || fail "The downloaded Compose checksum is not valid."
  [[ "${actual_checksum}" == "${expected_checksum}" ]] \
    || fail "Docker Compose checksum verification failed."

  as_root install -d -m 0755 /usr/local/lib/docker/cli-plugins
  as_root install -m 0755 \
    "${downloaded_binary}" \
    /usr/local/lib/docker/cli-plugins/docker-compose

  rm -rf -- "${temporary_dir}"
  COMPOSE_DOWNLOAD_DIR=""
}

[[ -r /etc/os-release ]] || fail "/etc/os-release is unavailable."
# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "amzn" || "${VERSION_ID:-}" != "2023" ]]; then
  fail "This bootstrap targets Amazon Linux 2023; detected ${PRETTY_NAME:-unknown Linux}."
fi

command -v dnf >/dev/null 2>&1 || fail "dnf is required on Amazon Linux 2023."

echo "[BOOTSTRAP] Installing Docker Engine and Git from Amazon Linux repositories"
as_root dnf install -y docker git

if ! command -v curl >/dev/null 2>&1; then
  as_root dnf install -y curl-minimal
fi
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required."

echo "[BOOTSTRAP] Enabling Docker at boot and starting it now"
as_root systemctl enable --now docker

docker_cmd version
if ! docker_cmd compose version >/dev/null 2>&1; then
  install_compose_plugin
fi

echo "[BOOTSTRAP] Docker Compose"
docker_cmd compose version
echo "[BOOTSTRAP] Git"
git --version
echo "[BOOTSTRAP] Host is ready. Docker commands intentionally use sudo/root access."
