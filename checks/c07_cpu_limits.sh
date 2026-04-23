#!/usr/bin/env bash
# checks/c07_cpu_limits.sh
# C07: Every container should have CPU limits set.

check_id="C07"
severity="MEDIUM"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

found_no_cpu_limit=0

while IFS= read -r id; do
  cpu_limit=$(docker inspect --format '{{.HostConfig.NanoCpus}}' "$id")
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  if [[ "$cpu_limit" -eq 0 ]]; then
    log_fail "$check_id" "$severity" "container '${name}' has no CPU limit set"
    found_no_cpu_limit=1
  fi
done <<< "$container_ids"

if [[ "$found_no_cpu_limit" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "all containers have CPU limits set"
fi