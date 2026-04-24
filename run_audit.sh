#!/usr/bin/env bash
# run_audit.sh — the foreman.
# Finds every check in checks/ and runs it, then prints a summary.

set -uo pipefail

# Figure out where this script lives, so paths work no matter where it's run from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="${SCRIPT_DIR}/checks"
LIB_DIR="${SCRIPT_DIR}/lib"
REPORT_DIR="${REPORT_DIR:-${SCRIPT_DIR}/reports}"
METRICS_DIR="${METRICS_DIR:-${SCRIPT_DIR}/metrics}"

# Pull in the shared clipboard (RESULT_* arrays, log_pass, log_fail).
source "${LIB_DIR}/helpers.sh"

echo "=== Compliance audit starting at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo

# Run every check in checks/ in alphabetical order (so c00 runs before c01, etc.)
for check_file in "${CHECKS_DIR}"/c*.sh; do
  if [[ -f "$check_file" ]]; then
    echo "Running $(basename "$check_file")"
    source "$check_file"
  fi
done

echo
echo "=== Summary ==="
compute_totals
echo "Passed: ${PASS_COUNT}"
echo "Failed: ${FAIL_COUNT}"

echo
write_text_report "$REPORT_DIR"
write_json_report "$REPORT_DIR"
write_prom_metrics "$METRICS_DIR"