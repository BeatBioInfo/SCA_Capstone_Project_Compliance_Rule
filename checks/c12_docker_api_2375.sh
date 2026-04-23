#!/usr/bin/env bash
# checks/c12_docker_api_2375.sh
# C12: The Docker daemon should not expose its API on TCP port 2375.

check_id="C12"
severity="CRITICAL"

if lsof -iTCP:2375 -sTCP:LISTEN >/dev/null 2>&1; then
  log_fail "$check_id" "$severity" "Docker API is listening on TCP 2375 (unencrypted, no auth)"
else
  log_pass "$check_id" "$severity" "Docker API is not exposed on TCP 2375"
fi