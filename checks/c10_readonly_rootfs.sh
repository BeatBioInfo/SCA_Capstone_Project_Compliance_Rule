#!/usr/bin/env bash
# checks/c10_readonly_rootfs.sh
# C10: Every container should have a read-only root filesystem.

check_id="C10"
severity="MEDIUM"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

found_writable_root=0

while IFS= read -r id; do
  readonly_rootfs=$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "$id")
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  if [[ "$readonly_rootfs" == "false" ]]; then
    log_fail "$check_id" "$severity" "container '${name}' has a writable root filesystem"
    found_writable_root=1
  fi
done <<< "$container_ids"

if [[ "$found_writable_root" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "all containers have read-only root filesystems"
fi