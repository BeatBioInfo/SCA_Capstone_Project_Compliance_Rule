#!/usr/bin/env bash
# checks/c11_no_host_network.sh
# C11: No container should use host network mode.

check_id="C11"
severity="HIGH"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

found_host_network=0

while IFS= read -r id; do
  network_mode=$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$id")
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  if [[ "$network_mode" == "host" ]]; then
    log_fail "$check_id" "$severity" "container '${name}' is using host network mode"
    found_host_network=1
  fi
done <<< "$container_ids"

if [[ "$found_host_network" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "no containers are using host network mode"
fi