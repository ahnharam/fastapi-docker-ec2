#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly HEALTH_URL="http://127.0.0.1/health"
readonly COURSES_URL="http://127.0.0.1/courses"

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
command -v curl >/dev/null 2>&1 || fail "curl is required."
docker_cmd compose version >/dev/null 2>&1 || fail "Docker Compose is unavailable."

container_id="$(docker_cmd compose --file docker-compose.yml ps --quiet api)"
[[ -n "${container_id}" ]] || fail "The api container is not running."

restart_policy="$(docker_cmd inspect --format '{{.HostConfig.RestartPolicy.Name}}' "${container_id}")"
[[ "${restart_policy}" == "always" ]] \
  || fail "Expected restart policy always; found ${restart_policy:-none}."

host_port="$(docker_cmd inspect --format '{{(index (index .HostConfig.PortBindings "8000/tcp") 0).HostPort}}' "${container_id}")"
[[ "${host_port}" == "80" ]] || fail "Expected host port 80; found ${host_port:-none}."

container_user="$(docker_cmd inspect --format '{{.Config.User}}' "${container_id}")"
case "${container_user}" in
  ""|0|0:0|root|root:root) fail "The application container is running as root." ;;
esac

echo "[VERIFY] Waiting for Docker health status"
health_status="unknown"
for _attempt in {1..20}; do
  health_status="$(docker_cmd inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "${container_id}")"
  if [[ "${health_status}" == "healthy" ]]; then
    break
  fi
  if [[ "${health_status}" == "unhealthy" ]]; then
    docker_cmd logs --tail 50 "${container_id}" >&2 || true
    fail "Container health check is unhealthy."
  fi
  sleep 2
done
[[ "${health_status}" == "healthy" ]] || fail "Container did not become healthy in time."

echo "[VERIFY] docker ps"
docker_cmd ps --filter "id=${container_id}" \
  --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo "[VERIFY] ${HEALTH_URL}"
curl --fail --silent --show-error --max-time 5 "${HEALTH_URL}"
echo
echo "[VERIFY] ${COURSES_URL}"
curl --fail --silent --show-error --max-time 5 "${COURSES_URL}"
echo
echo "[VERIFY] PASS · restart=${restart_policy} · host_port=${host_port} · user=${container_user}"
