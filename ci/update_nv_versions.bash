#!/usr/bin/env bash
# Merge existing nv-versions.json with the current deploy version and write updated manifest.
# Usage: update_nv_versions.bash --existing-json PATH --new-version VER --base-url URL --output PATH
set -euo pipefail

EXISTING_JSON=""
NEW_VERSION=""
BASE_URL=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --existing-json) EXISTING_JSON="$2"; shift 2 ;;
    --new-version)   NEW_VERSION="$2";   shift 2 ;;
    --base-url)      BASE_URL="$2";      shift 2 ;;
    --output)        OUTPUT="$2";        shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

for var in EXISTING_JSON NEW_VERSION BASE_URL OUTPUT; do
  if [[ -z "${!var}" ]]; then
    echo "Missing required argument: --${var,,}" >&2
    exit 1
  fi
done

# Normalize base URL (trailing slash)
BASE_URL="${BASE_URL%/}/"

# Load existing or empty array
if [[ -f "${EXISTING_JSON}" ]]; then
  existing=$(cat "${EXISTING_JSON}")
else
  existing="[]"
fi

# Ensure new version is in the list
merged=$(echo "${existing}" | jq --arg ver "${NEW_VERSION}" --arg url "${BASE_URL}${NEW_VERSION}/" '
  . as $in |
  ([.[].version] | index($ver)) as $idx |
  if $idx then $in
  else . + [{ name: $ver, version: $ver, url: $url, latest: false, preferred: false }]
  end
')

# Validate: only "unstable" or semver
invalid=$(echo "${merged}" | jq -r '.[] | select(.version != "unstable" and (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$") | not)) | .version')
if [[ -n "${invalid}" ]]; then
  echo "Invalid version(s) in nv-versions (allowed: unstable or X.Y.Z): ${invalid}" >&2
  exit 1
fi

# Sort: unstable first, then semvers ascending; mark newest semver (or unstable) as latest/preferred
result=$(echo "${merged}" | jq -c '
  (map(select(.version == "unstable")) + (map(select(.version != "unstable")) | sort_by(.version | split(".") | map(tonumber)))) as $sorted |
  ($sorted | map(select(.version != "unstable")) | last.version // "unstable") as $latest_ver |
  $sorted | map(if .version == $latest_ver then . + { latest: true, preferred: true } else . + { latest: false, preferred: false } end)
')

echo "${result}" > "${OUTPUT}"
