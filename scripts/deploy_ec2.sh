#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

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

cd "${PROJECT_DIR}"
[[ -f Dockerfile ]] || fail "Dockerfile is missing from ${PROJECT_DIR}."
[[ -f docker-compose.yml ]] || fail "docker-compose.yml is missing from ${PROJECT_DIR}."

docker_cmd info >/dev/null
docker_cmd compose version >/dev/null 2>&1 \
  || fail "Docker Compose is unavailable. Run bash scripts/bootstrap_host.sh first."

echo "[DEPLOY] Building the image and starting the service on host port 80"
docker_cmd compose --file docker-compose.yml up --build --detach --remove-orphans

echo "[DEPLOY] Current Compose state"
docker_cmd compose --file docker-compose.yml ps

echo "[DEPLOY] Running deployment verification"
bash "${SCRIPT_DIR}/verify_deployment.sh"
