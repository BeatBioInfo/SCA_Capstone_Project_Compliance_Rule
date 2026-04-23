#!/usr/bin/env bash
# checks/c06_disk_usage.sh
# C06: Host disk usage should be below DISK_THRESHOLD (default 80%).

check_id="C06"
severity="MEDIUM"

# Threshold is configurable via env var, defaults to 80%.
threshold="${DISK_THRESHOLD:-80}"

# Extract disk usage percentage from the root filesystem.
# df -h /          → prints two lines with disk info for root
# awk 'NR==2 ...'  → grabs column 5 (Capacity) from the second line
# tr -d '%'        → strips the trailing percent sign
# End result: a plain integer like "12"
usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

if [[ "$usage" -gt "$threshold" ]]; then
  log_fail "$check_id" "$severity" "disk usage is ${usage}% (threshold: ${threshold}%)"
else
  log_pass "$check_id" "$severity" "disk usage is ${usage}% (threshold: ${threshold}%)"
fi