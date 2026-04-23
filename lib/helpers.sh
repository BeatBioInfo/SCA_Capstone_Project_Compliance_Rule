#!/usr/bin/env bash
# lib/helpers.sh
# Shared functions used by every check.
# Not run directly — the foreman (run_audit.sh) pulls it in.

# The clipboard. Starts empty. Each check appends one line to it.
RESULTS=()

# Called by a check when it passes.
# Arguments: check_id, severity, message
log_pass() {
  local check_id="$1"
  local severity="$2"
  local message="$3"
  RESULTS+=("PASS|${check_id}|${severity}|${message}")
  echo "  [PASS] ${check_id} — ${message}"
}

# Called by a check when it fails.
log_fail() {
  local check_id="$1"
  local severity="$2"
  local message="$3"
  RESULTS+=("FAIL|${check_id}|${severity}|${message}")
  echo "  [FAIL] ${check_id} (${severity}) — ${message}"
}