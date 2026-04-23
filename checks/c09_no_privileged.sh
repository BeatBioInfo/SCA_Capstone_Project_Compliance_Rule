#!/usr/bin/env bash
# checks/c09_no_privileged.sh
# C09: No running container should be started with --privileged.

check_id="C09"
severity="CRITICAL"

# Get the list of running container IDs, one per line.
# `docker ps -q` prints only IDs (the -q flag = "quiet", no table headers).
container_ids=$(docker ps -q)

# If there are no running containers, the rule trivially passes.
if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

# Track whether we saw any offender in the loop.
found_privileged=0

# Loop over each container ID.
while IFS= read -r id; do
  # Ask Docker: is this container privileged?
  privileged=$(docker inspect --format '{{.HostConfig.Privileged}}' "$id")
  # Also grab the container's name for a nicer error message.
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  if [[ "$privileged" == "true" ]]; then
    log_fail "$check_id" "$severity" "container '${name}' is running with --privileged"
    found_privileged=1
  fi
done <<< "$container_ids"

# If nothing was flagged, log one overall pass for the rule.
if [[ "$found_privileged" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "no privileged containers found"
fi