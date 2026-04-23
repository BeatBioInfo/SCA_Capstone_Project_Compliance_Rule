#!/usr/bin/env bash
# checks/c00_docker_installed.sh
# Prerequisite check — is the docker command available at all?

check_id="C00"
severity="CRITICAL"

if command -v docker >/dev/null 2>&1; then
  log_pass "$check_id" "$severity" "docker binary found in PATH"
else
  log_fail "$check_id" "$severity" "docker binary not found"
fi