#!/usr/bin/env bash
# checks/c05_no_plaintext_secrets.sh
# C05: No container should pass secrets as plaintext environment variables.

check_id="C05"
severity="CRITICAL"

# Case-insensitive substrings that suggest a secret. Override via env var.
secret_patterns_raw="${SECRET_PATTERNS:-PASSWORD,PASSWD,PWD,SECRET,TOKEN,KEY,APIKEY,CREDENTIAL,CREDS}"
IFS=',' read -ra secret_patterns <<< "$secret_patterns_raw"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

found_secret=0

while IFS= read -r id; do
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')

  # Get every env var as NAME=VALUE on its own line.
  env_lines=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$id")

  while IFS= read -r line; do
    # Skip blank lines (trailing newline from the template).
    [[ -z "$line" ]] && continue

    # Split off just the variable name (everything before the first =).
    var_name="${line%%=*}"
    # Uppercase it for case-insensitive matching.
    var_name_upper="$(echo "$var_name" | tr '[:lower:]' '[:upper:]')"

    # Compare against every pattern.
    for pat in "${secret_patterns[@]}"; do
      pat_upper="$(echo "$pat" | tr '[:lower:]' '[:upper:]')"
      if [[ "$var_name_upper" == *"$pat_upper"* ]]; then
        log_fail "$check_id" "$severity" "container '${name}' exposes a likely secret in env var '${var_name}'"
        found_secret=1
        break
      fi
    done
  done <<< "$env_lines"
done <<< "$container_ids"

if [[ "$found_secret" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "no containers expose likely secrets in env vars"
fi