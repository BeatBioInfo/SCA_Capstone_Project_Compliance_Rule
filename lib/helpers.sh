#!/usr/bin/env bash
# lib/helpers.sh
# Shared functions used by every check.
# Not run directly — the foreman (run_audit.sh) pulls it in.

# Four parallel arrays. Each finding has the same index in all four.
# RESULT_STATUSES[i]   = "PASS" or "FAIL"
# RESULT_CHECK_IDS[i]  = e.g. "C01"
# RESULT_SEVERITIES[i] = "CRITICAL" | "HIGH" | "MEDIUM"
# RESULT_MESSAGES[i]   = human-readable explanation
RESULT_STATUSES=()
RESULT_CHECK_IDS=()
RESULT_SEVERITIES=()
RESULT_MESSAGES=()

# Totals — populated by compute_totals(). Initialised here so references
# won't crash under `set -u` if a writer is called before compute_totals.
TOTAL_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
CRIT_FAIL=0
HIGH_FAIL=0
MED_FAIL=0

log_pass() {
  local check_id="$1"
  local severity="$2"
  local message="$3"
  RESULT_STATUSES+=("PASS")
  RESULT_CHECK_IDS+=("$check_id")
  RESULT_SEVERITIES+=("$severity")
  RESULT_MESSAGES+=("$message")
  echo "  [PASS] ${check_id} — ${message}"
}

log_fail() {
  local check_id="$1"
  local severity="$2"
  local message="$3"
  RESULT_STATUSES+=("FAIL")
  RESULT_CHECK_IDS+=("$check_id")
  RESULT_SEVERITIES+=("$severity")
  RESULT_MESSAGES+=("$message")
  echo "  [FAIL] ${check_id} (${severity}) — ${message}"
}

# Computes totals from the parallel result arrays.
# Sets globals: TOTAL_COUNT, PASS_COUNT, FAIL_COUNT, CRIT_FAIL, HIGH_FAIL, MED_FAIL.
# Call this once at the end of the audit, before any writer.
compute_totals() {
  TOTAL_COUNT="${#RESULT_STATUSES[@]}"
  PASS_COUNT=0
  FAIL_COUNT=0
  CRIT_FAIL=0
  HIGH_FAIL=0
  MED_FAIL=0

  for i in "${!RESULT_STATUSES[@]}"; do
    if [[ "${RESULT_STATUSES[$i]}" == "PASS" ]]; then
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      case "${RESULT_SEVERITIES[$i]}" in
        CRITICAL) CRIT_FAIL=$((CRIT_FAIL + 1)) ;;
        HIGH)     HIGH_FAIL=$((HIGH_FAIL + 1)) ;;
        MEDIUM)   MED_FAIL=$((MED_FAIL + 1)) ;;
      esac
    fi
  done
}

write_text_report() {
  local report_dir="$1"
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local safe_ts="${timestamp//:/}"
  local report_file="${report_dir}/audit-${safe_ts}.txt"
  local host
  host=$(hostname)

  mkdir -p "$report_dir"

  {
    echo "Compliance Audit Report"
    echo "======================="
    echo "Timestamp: ${timestamp}"
    echo "Host: ${host}"
    echo "Total checks: ${TOTAL_COUNT}"
    echo "Passed: ${PASS_COUNT}"
    echo "Failed: ${FAIL_COUNT}"
    echo
    echo "--- Findings ---"
    for i in "${!RESULT_STATUSES[@]}"; do
      printf "[%s] %s (%s) — %s\n" \
        "${RESULT_STATUSES[$i]}" \
        "${RESULT_CHECK_IDS[$i]}" \
        "${RESULT_SEVERITIES[$i]}" \
        "${RESULT_MESSAGES[$i]}"
    done
    echo
    echo "--- Failures by severity ---"
    echo "CRITICAL: ${CRIT_FAIL}"
    echo "HIGH:     ${HIGH_FAIL}"
    echo "MEDIUM:   ${MED_FAIL}"
  } > "$report_file"

  echo "Wrote text report: ${report_file}"
}

write_json_report() {
  local report_dir="$1"
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local safe_ts="${timestamp//:/}"
  local report_file="${report_dir}/audit-${safe_ts}.json"
  local host
  host=$(hostname)

  mkdir -p "$report_dir"

  # Build the findings array: one JSON object per finding, then slurp into an array.
  local findings_json
  findings_json=$(
    for i in "${!RESULT_STATUSES[@]}"; do
      jq -n \
        --arg status   "${RESULT_STATUSES[$i]}" \
        --arg id       "${RESULT_CHECK_IDS[$i]}" \
        --arg severity "${RESULT_SEVERITIES[$i]}" \
        --arg message  "${RESULT_MESSAGES[$i]}" \
        '{status: $status, check_id: $id, severity: $severity, message: $message}'
    done | jq -s '.'
  )

  # Assemble and write the full report.
  jq -n \
    --arg timestamp "$timestamp" \
    --arg host      "$host" \
    --argjson findings "$findings_json" \
    --argjson passed $PASS_COUNT \
    --argjson failed $FAIL_COUNT \
    --argjson total  $TOTAL_COUNT \
    --argjson crit   $CRIT_FAIL \
    --argjson high   $HIGH_FAIL \
    --argjson med    $MED_FAIL \
    '{
      timestamp: $timestamp,
      host: $host,
      summary: {
        total: $total,
        passed: $passed,
        failed: $failed,
        failures_by_severity: {
          CRITICAL: $crit,
          HIGH: $high,
          MEDIUM: $med
        }
      },
      findings: $findings
    }' > "$report_file"

  echo "Wrote JSON report: ${report_file}"
}

write_prom_metrics() {
  local metrics_dir="$1"
  local metrics_file="${metrics_dir}/compliance.prom"
  local now_epoch
  now_epoch=$(date -u +%s)

  mkdir -p "$metrics_dir"

  local tmp_file
  tmp_file=$(mktemp "${metrics_file}.XXXXXX")

  {
    echo "# HELP compliant_checks Number of findings that passed in the latest audit."
    echo "# TYPE compliant_checks gauge"
    echo "compliant_checks ${PASS_COUNT}"
    echo
    echo "# HELP failed_checks Number of findings that failed in the latest audit."
    echo "# TYPE failed_checks gauge"
    echo "failed_checks ${FAIL_COUNT}"
    echo
    echo "# HELP compliance_failures_critical Number of CRITICAL severity failures in the latest audit."
    echo "# TYPE compliance_failures_critical gauge"
    echo "compliance_failures_critical ${CRIT_FAIL}"
    echo
    echo "# HELP compliance_failures_high Number of HIGH severity failures in the latest audit."
    echo "# TYPE compliance_failures_high gauge"
    echo "compliance_failures_high ${HIGH_FAIL}"
    echo
    echo "# HELP compliance_failures_medium Number of MEDIUM severity failures in the latest audit."
    echo "# TYPE compliance_failures_medium gauge"
    echo "compliance_failures_medium ${MED_FAIL}"
    echo
    echo "# HELP last_audit_timestamp Unix epoch seconds of when the latest audit completed."
    echo "# TYPE last_audit_timestamp gauge"
    echo "last_audit_timestamp ${now_epoch}"
  } > "$tmp_file"

  mv "$tmp_file" "$metrics_file"
  echo "Wrote Prometheus metrics: ${metrics_file}"
}