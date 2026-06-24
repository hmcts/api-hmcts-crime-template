#!/usr/bin/env bash
#
# import-rulesets.sh
# Copy all repository rulesets from THIS repo (the template this script lives in)
# to a target repo. Lives permanently in the template repo.
#
# Usage:
#   ./import-rulesets.sh <target-repo-name>
#
# Examples:
#   ./import-rulesets.sh api-hmcts-crime-new
#
# Source is always auto-detected from the git 'origin' remote of this repo.
# Target is always under the hmcts/ organisation.
#
# Requires: gh (authenticated, `gh auth login`) and jq.

set -euo pipefail

TARGET_NAME="${1:-}"

if [[ -z "$TARGET_NAME" ]]; then
  echo "Error: target repo name required."
  echo "Usage: $0 <target-repo-name>"
  exit 1
fi

TARGET="hmcts/$TARGET_NAME"

for cmd in gh jq git; do
  command -v "$cmd" >/dev/null || { echo "Error: '$cmd' not found on PATH."; exit 1; }
done

# Auto-detect source from the origin remote of the repo this script sits in.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
origin="$(git -C "$script_dir" remote get-url origin 2>/dev/null || true)"
# Normalise git@github.com:owner/repo.git or https://github.com/owner/repo(.git)
SOURCE="$(sed -E 's#^.*github\.com[:/]##; s#\.git$##' <<<"$origin")"
if [[ -z "$SOURCE" ]]; then
  echo "Error: could not detect source repo from git origin."
  exit 1
fi

echo "Source (template): $SOURCE"
echo "Target:            $TARGET"
echo

# Fields the create API accepts. Everything else (id, source, created_at, _links, etc.) is dropped.
FILTER='{name, target, enforcement, conditions, rules, bypass_actors}'

# Names already present on target, so we skip duplicates.
EXISTING=()
while IFS= read -r line; do
  [[ -n "$line" ]] && EXISTING+=("$line")
done < <(gh api "repos/$TARGET/rulesets" --paginate -q '.[].name' 2>/dev/null || true)

# List ruleset IDs + names on the source repo.
RULESETS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && RULESETS+=("$line")
done < <(gh api "repos/$SOURCE/rulesets" --paginate -q '.[] | "\(.id)\t\(.name)"')

if [[ ${#RULESETS[@]} -eq 0 ]]; then
  echo "No rulesets found on $SOURCE. Nothing to do."
  exit 0
fi

for row in "${RULESETS[@]}"; do
  id="${row%%$'\t'*}"
  name="${row#*$'\t'}"

  if printf '%s\n' "${EXISTING[@]}" | grep -Fxq "$name"; then
    echo "Skipping '$name' — already exists on $TARGET"
    continue
  fi

  echo "Importing ruleset: $name (source id $id)"
  body="$(gh api "repos/$SOURCE/rulesets/$id" | jq "$FILTER")"

  if gh api "repos/$TARGET/rulesets" --method POST --input - <<<"$body" >/dev/null; then
    echo "  ✓ created on $TARGET"
  else
    echo "  ✗ failed"
  fi
done

echo

# Remove this script from the target repo if it exists there.
script_name="$(basename "${BASH_SOURCE[0]}")"
if gh api "repos/$TARGET/contents/$script_name" >/dev/null 2>&1; then
  echo "Removing $script_name from $TARGET..."
  sha="$(gh api "repos/$TARGET/contents/$script_name" -q '.sha')"
  gh api "repos/$TARGET/contents/$script_name" --method DELETE \
    --field message="chore: remove $script_name after ruleset import" \
    --field sha="$sha" >/dev/null
  echo "  ✓ deleted"
fi

echo "Done."
