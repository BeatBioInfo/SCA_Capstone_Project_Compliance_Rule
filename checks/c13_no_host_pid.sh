#!/usr/bin/env bash
# checks/c13_no_host_pid.sh
# C13: No container should share the host PID namespace.

check_id="C13"
severity="HIGH"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

found_host_pid=0

while IFS= read -r id; do
  pid_mode=$(docker inspect --format '{{.HostConfig.PidMode}}' "$id")
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  if [[ "$pid_mode" == "host" ]]; then
    log_fail "$check_id" "$severity" "container '${name}' is sharing the host PID namespace"
    found_host_pid=1
  fi
done <<< "$container_ids"

if [[ "$found_host_pid" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "no containers are sharing the host PID namespace"
fi