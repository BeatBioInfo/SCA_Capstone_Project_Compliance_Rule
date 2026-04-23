#!/usr/bin/env bash
# checks/c01_no_root.sh
# C01: No container should run as root (UID 0).

check_id="C01"
severity="HIGH"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

found_root=0

while IFS= read -r id; do
  user=$(docker inspect --format '{{.Config.User}}' "$id")
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  # Empty, "0", or "root" all mean the container is running as root.
  if [[ -z "$user" || "$user" == "0" || "$user" == "root" ]]; then
    # Show "(unset)" in the message when the field is empty — clearer than blank.
    display_user="${user:-unset}"
    log_fail "$check_id" "$severity" "container '${name}' is running as root (user=${display_user})"
    found_root=1
  fi
done <<< "$container_ids"

if [[ "$found_root" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "no containers running as root"
fi