#!/usr/bin/env bash
# Prints the release tag of a commit on a release branch, or nothing when it
# holds nothing to release:
#   next-version.sh alpha|beta|rc|stable PRS.json [ref]
#
# PRS.json is the output of
#   gh pr list --state merged --json number,labels,mergeCommit,headRefName
#
# The version is the last stable release bumped by the highest release:* label
# among the pull requests merged since. Promotions (from alpha, beta, rc) and
# back-merges carry changes whose own pull requests already count. A stage with
# no labelled change since its last release (release:none only) releases nothing.
# Before the first stable release, the version is FIRST_VERSION.
set -euo pipefail

FIRST_VERSION=${FIRST_VERSION:-2.0.0}
train=${1:?usage: next-version.sh alpha|beta|rc|stable PRS.json [ref]}
prs=${2:?missing PRS.json}
ref=${3:-HEAD}

stable_re='^v[0-9]+\.[0-9]+\.[0-9]+$'
case $train in
  alpha | beta | rc) own="^v[0-9]+\.[0-9]+\.[0-9]+-$train\.[0-9]+$" ;;
  stable) own=$stable_re ;;
  *) echo "unknown train '$train'" >&2; exit 2 ;;
esac

# Upstream's v1.x tags are not releases of this fork.
ours() { awk -F. -v min="${FIRST_VERSION%%.*}" 'substr($1, 2) + 0 >= min'; }

# A re-run publishes the same version again.
existing=$(git tag --points-at "$ref" | { grep -E "$own" || true; } | ours | sort -V | tail -n1)
if [ -n "$existing" ]; then
  echo "$existing"
  exit 0
fi

last_stable=$(git tag --list 'v*' | { grep -E "$stable_re" || true; } | ours | sort -V | tail -n1)
last_own=$(git tag --merged "$ref" | { grep -E "$own" || true; } | ours | sort -V | tail -n1)

# Highest bump (0 none, 1 patch, 2 minor, 3 major) of the pull requests whose
# merge commit is in $ref and not in $1.
bump_since() {
  local range=("$ref")
  [ -z "$1" ] || range+=("^$1")
  git rev-list "${range[@]}" | jq -Rn --slurpfile prs "$prs" '
    [inputs] | map({(.): true}) | add // {} | . as $in
    | [ $prs[0][]
        | select(.mergeCommit != null and $in[.mergeCommit.oid])
        | select(.headRefName | test("^(alpha|beta|rc)$|^backmerge/") | not)
        | .labels[].name
        | {"release:major": 3, "release:minor": 2, "release:patch": 1}[.] // 0
      ] | max // 0'
}

bump=$(bump_since "$last_stable")
[ "$bump" -gt 0 ] || exit 0
[ "$(bump_since "$last_own")" -gt 0 ] || exit 0

if [ -z "$last_stable" ]; then
  next=v$FIRST_VERSION
else
  IFS=. read -r major minor patch <<<"${last_stable#v}"
  case $bump in
    3) next=v$((major + 1)).0.0 ;;
    2) next=v$major.$((minor + 1)).0 ;;
    1) next=v$major.$minor.$((patch + 1)) ;;
  esac
fi

if [ "$train" = stable ]; then
  echo "$next"
  exit 0
fi
n=$(git tag --list "$next-$train.*" | sed "s/^$next-$train\.//" | sort -n | tail -n1)
echo "$next-$train.$((${n:-0} + 1))"
