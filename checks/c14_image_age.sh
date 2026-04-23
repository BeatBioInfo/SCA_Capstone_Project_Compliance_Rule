#!/usr/bin/env bash
# checks/c14_image_age.sh
# C14: Container images should not be older than 90 days (measured from image build time).

check_id="C14"
severity="MEDIUM"

# Max image age in days. Override via env var.
max_age_days="${MAX_IMAGE_AGE_DAYS:-90}"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

found_stale=0

while IFS= read -r id; do
   image=$(docker inspect --format '{{.Config.Image}}' "$id")
   image_id=$(docker inspect --format '{{.Image}}' "$id")
   created=$(docker image inspect --format '{{.Created}}' "$image_id" 2>/dev/null)

  if [[ -z "$created" ]]; then
    log_fail "$check_id" "$severity" "container '${name}': could not read image build date"
    found_stale=1
    continue
  fi

# Strip fractional seconds before passing to jq — macOS jq doesn't handle them.
  created_trimmed="${created%.*}Z"
  age_days=$(jq -r --arg d "$created_trimmed" 'now - ($d | fromdateiso8601) | . / 86400 | floor' <<< 'null')
  
if ! [[ "$age_days" =~ ^[0-9]+$ ]]; then
  log_fail "$check_id" "$severity" "container '${name}': could not compute image age from '${created}'"
  found_stale=1
elif [[ "$age_days" -gt "$max_age_days" ]]; then
  log_fail "$check_id" "$severity" "container '${name}' uses image '${image}' which is ${age_days} days old (max: ${max_age_days})"
  found_stale=1
fi

done <<< "$container_ids"

if [[ "$found_stale" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "all container images are within the age threshold"
fi