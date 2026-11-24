#!/usr/bin/env bash
# Which branches may target which stage, and the release label a pull request
# needs. BASE, HEAD, SAME_REPO (true/false) and LABELS (one per line) come from
# the environment.
set -euo pipefail

fail() { echo "::error::$1"; exit 1; }

# A fork can name its branch anything: only this repository's count.
# shellcheck disable=SC2153 # HEAD is an input
head=$HEAD
[ "$SAME_REPO" = true ] || head="fork:$HEAD"

case $BASE in
  alpha) ;;
  beta) [[ $head =~ ^(alpha|(fix|hotfix)/.+|backmerge/rc-to-beta)$ ]] || fail "beta takes alpha, fix/*, hotfix/* and back-merges, not $head" ;;
  rc) [[ $head =~ ^(beta|(fix|hotfix)/.+|backmerge/main-to-rc)$ ]] || fail "rc takes beta, fix/*, hotfix/* and back-merges, not $head" ;;
  main) [[ $head =~ ^(rc|hotfix/.+)$ ]] || fail "main takes rc and hotfix/* only, not $head: open the pull request against alpha" ;;
  *) fail "$BASE is not a release branch" ;;
esac

# Their changes were labelled in their own pull requests.
if [[ $head =~ ^(alpha|beta|rc)$ || $head == backmerge/* ]]; then
  echo "$head to $BASE: no release label needed"
  exit 0
fi

count=$(grep -cE '^release:(major|minor|patch|none)$' <<<"$LABELS" || true)
[ "$count" -eq 1 ] || fail "set exactly one of release:major, release:minor, release:patch, release:none ($count set)"
echo "$head to $BASE: ok"
