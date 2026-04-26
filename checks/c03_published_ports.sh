#!/usr/bin/env bash
# checks/c03_published_ports.sh
# C03: No container should publish a port outside the allowlist.

check_id="C03"
severity="HIGH"

# Allowed host ports, comma-separated. Override via env var.
allowed_raw="${ALLOWED_PORTS:-80,443,8080,8443}"
IFS=',' read -ra allowed_ports <<< "$allowed_raw"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  # shellcheck disable=SC2317  # `exit 0` reached only when this file is run directly, not sourced.
  return 0 2>/dev/null || exit 0
fi

# Helper: is the given port in the allowlist?
is_allowed() {
  local port="$1"
  for allowed in "${allowed_ports[@]}"; do
    if [[ "$port" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

found_bad_port=0

while IFS= read -r id; do
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  # Pull every published host port from this container's JSON.
  published_ports=$(docker inspect --format '{{json .NetworkSettings.Ports}}' "$id" \
    | jq -r '. | to_entries[] | select(.value != null) | .value[].HostPort')

  # If no ports published, nothing to check for this container.
  if [[ -z "$published_ports" ]]; then
    continue
  fi

  while IFS= read -r port; do
    if ! is_allowed "$port"; then
      log_fail "$check_id" "$severity" "container '${name}' publishes disallowed port ${port}"
      found_bad_port=1
    fi
  done <<< "$published_ports"
done <<< "$container_ids"

if [[ "$found_bad_port" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "no containers publish disallowed ports"
fi