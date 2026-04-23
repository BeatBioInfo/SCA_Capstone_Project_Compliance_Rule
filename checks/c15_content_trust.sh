#!/usr/bin/env bash
# checks/c15_content_trust.sh
# C15: DOCKER_CONTENT_TRUST should be enabled.

check_id="C15"
severity="MEDIUM"

content_trust="${DOCKER_CONTENT_TRUST:-}"

if [[ "$content_trust" == "1" ]]; then
  log_pass "$check_id" "$severity" "DOCKER_CONTENT_TRUST is enabled"
else
  log_fail "$check_id" "$severity" "DOCKER_CONTENT_TRUST is not set to 1 (current value: '${content_trust}')"
fi