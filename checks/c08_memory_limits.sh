#!/usr/bin/env bash
# checks/c08_memory_limits.sh
# C08: Every container should have memory limits set.

check_id="C08"
severity="MEDIUM"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  # shellcheck disable=SC2317  # `exit 0` reached only when this file is run directly, not sourced.
  return 0 2>/dev/null || exit 0
fi

found_no_memory_limit=0

while IFS= read -r id; do
  memory_limit=$(docker inspect --format '{{.HostConfig.Memory}}' "$id")
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  if [[ "$memory_limit" -eq 0 ]]; then
    log_fail "$check_id" "$severity" "container '${name}' has no memory limit set"
    found_no_memory_limit=1
  fi
done <<< "$container_ids"

if [[ "$found_no_memory_limit" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "all containers have memory limits set"
fi