#!/usr/bin/env bash
# checks/c04_trusted_registries.sh
# C04: Container images should come from trusted registries only.

check_id="C04"
severity="HIGH"

# Trusted registry prefixes, comma-separated. Override via env var.
trusted_raw="${TRUSTED_REGISTRIES:-docker.io/library,docker.io/myorg,ghcr.io/myorg}"
IFS=',' read -ra trusted_prefixes <<< "$trusted_raw"

container_ids=$(docker ps -q)

if [[ -z "$container_ids" ]]; then
  log_pass "$check_id" "$severity" "no running containers to audit"
  return 0 2>/dev/null || exit 0
fi

# Normalize bare and short image names into their full docker.io form.
normalize_image() {
  local img="$1"
  img="${img%%:*}"
  img="${img%%@*}"
  local slashes="${img//[^\/]/}"
  local count="${#slashes}"
  if [[ "$count" -eq 0 ]]; then
    echo "docker.io/library/${img}"
  elif [[ "$count" -eq 1 ]]; then
    local first="${img%%/*}"
    if [[ "$first" == *.* || "$first" == *:* ]]; then
      echo "$img"
    else
      echo "docker.io/${img}"
    fi
  else
    echo "$img"
  fi
}

found_untrusted=0

while IFS= read -r id; do
  image=$(docker inspect --format '{{.Config.Image}}' "$id")
  name=$(docker inspect --format '{{.Name}}' "$id" | sed 's|^/||')
  normalized=$(normalize_image "$image")

  # Check if the normalized image starts with any trusted prefix.
  matched=0
  for prefix in "${trusted_prefixes[@]}"; do
    if [[ "$normalized" == "${prefix}"* || "$normalized" == "${prefix}/"* ]]; then
      matched=1
      break
    fi
  done

  if [[ "$matched" -eq 0 ]]; then
    log_fail "$check_id" "$severity" "container '${name}' uses untrusted image '${image}' (normalized: ${normalized})"
    found_untrusted=1
  fi
done <<< "$container_ids"

if [[ "$found_untrusted" -eq 0 ]]; then
  log_pass "$check_id" "$severity" "all container images come from trusted registries"
fi