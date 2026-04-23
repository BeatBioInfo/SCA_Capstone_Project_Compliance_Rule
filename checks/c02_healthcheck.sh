#!/usr/bin/env bash
# checks/c02_healthcheck.sh
# C02: Every container should have a HEALTHCHECK defined.

check_id="C02"
severity="MEDIUM"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

found_no_healthcheck=0

while IFS= read -r id; do
  healthcheck=$(docker inspect --format '{{.Config.Healthcheck}}' "$id")
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  if [[ "$healthcheck" == "<nil>" || -z "$healthcheck" ]]; then
    log_fail "$check_id" "$severity" "container '${name}' has no HEALTHCHECK defined"
    found_no_healthcheck=1
  fi
done <<< "$container_ids"

if [[ "$found_no_healthcheck" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "all containers have a HEALTHCHECK defined"
fi