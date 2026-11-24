#!/usr/bin/env bash
# Opens, or brings up to date, a pull request that merges one ref into a branch:
#   open-merge-pr.sh BASE SOURCE_REF BRANCH TITLE BODY [LABEL]
# A clean merge is pushed as a merge of BASE and SOURCE, so it is up to date with
# its base. Files deleted by this fork (.github/fork-removed-files.txt) stay
# deleted. Any other conflict pushes SOURCE as it is and leaves the pull request
# to be resolved by hand. Needs GH_TOKEN, and a checkout with the full history.
set -euo pipefail
base=$1 source=$2 branch=$3 title=$4 body=$5 label=${6:-}

# The helper runs in git's shell, so the token stays off the command line.
# shellcheck disable=SC2016
helper='!f() { echo username=x-access-token; echo "password=$GH_TOKEN"; }; f'
note=''

git fetch -q origin "$base"
start=$(git rev-parse FETCH_HEAD)
number=$(gh pr list --state open --base "$base" --head "$branch" --json number --jq '.[0].number // empty')
if [ -n "$number" ]; then
  git fetch -q origin "$branch"
  start=$(git rev-parse FETCH_HEAD)
fi
if git merge-base --is-ancestor "$source" "$start"; then
  echo "$source is already in ${number:+#$number, }$base or its pull request"
  exit 0
fi

git checkout -q --detach "$start"
# Without rename detection: git would take a file this fork deleted for a renamed
# one, and apply upstream's edits of security-scan.yml to security.yml.
git merge --no-ff -X no-renames -m "$title" "$source" || true
if [ -f .github/fork-removed-files.txt ]; then
  while IFS= read -r file; do
    if git ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then
      git rm -qrf -- "$file"
    fi
  done < <(grep -vE '^(#|$)' .github/fork-removed-files.txt || true)
fi
conflicts=$(git diff --name-only --diff-filter=U)
if [ -n "$conflicts" ]; then
  git merge --abort
  if [ -n "$number" ]; then
    echo "::warning::#$number is open and $source no longer merges cleanly into it"
    exit 0
  fi
  note="**This merge has conflicts.** Resolve them by merging \`$base\` into \`$branch\`:
\`\`\`
$conflicts
\`\`\`"
  git checkout -q --detach "$source"
elif git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  git commit -q --no-edit
elif ! git diff --cached --quiet; then
  git commit -q --amend --no-edit
fi
[ "$(git rev-parse HEAD)" != "$start" ] || { echo "::error::the merge of $source failed"; exit 1; }

# Without an open pull request the branch is a leftover of an earlier one.
force=()
[ -n "$number" ] || force=(--force)
git -c "credential.helper=$helper" push "${force[@]+"${force[@]}"}" origin "HEAD:refs/heads/$branch"
if [ -z "$number" ]; then
  gh pr create --base "$base" --head "$branch" --title "$title" --body "$body${note:+

$note}" ${label:+--label "$label"}
fi
