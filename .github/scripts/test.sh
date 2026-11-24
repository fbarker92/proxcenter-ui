#!/usr/bin/env bash
# Tests next-version.sh and check-pr.sh in a throwaway repository.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q -b main .
git config user.email ci@example.invalid
git config user.name ci
echo '[]' >prs.json

eq() { [ "$2" = "$3" ] || { echo "FAIL $1: expected '$2', got '$3'"; exit 1; }; echo "ok   $1"; }
next() { "$here/next-version.sh" "$1" prs.json "$2"; }
commit() { git commit -q --allow-empty -m "$1"; }
# pr <head branch> <label>: records HEAD as the merge commit of a pull request.
pr() {
  jq --arg o "$(git rev-parse HEAD)" --arg h "$1" --arg l "$2" \
    '. + [{headRefName: $h, mergeCommit: {oid: $o}, labels: (if $l == "" then [] else [{name: $l}] end)}]' prs.json >p && mv p prs.json
}
merge() { git checkout -q "$2"; git merge -q --no-ff -m "merge $1" "$1"; }

commit upstream; git tag v1.5.0; pr ci/x release:none
for b in alpha beta rc; do git branch $b; done
eq 'nothing to release at first' '' "$(next alpha alpha)"

git checkout -q alpha; commit f1; pr feat/a release:minor
eq 'first release is 2.0.0 whatever the label' v2.0.0-alpha.1 "$(next alpha alpha)"
git tag v2.0.0-alpha.1
eq 're-run keeps the tag' v2.0.0-alpha.1 "$(next alpha alpha)"
commit d; pr docs/x release:none
eq 'release:none releases nothing' '' "$(next alpha alpha)"
commit f2; pr fix/b release:patch
eq 'alpha counts on' v2.0.0-alpha.2 "$(next alpha alpha)"; git tag v2.0.0-alpha.2

merge alpha beta; pr alpha ''; eq 'beta' v2.0.0-beta.1 "$(next beta beta)"; git tag v2.0.0-beta.1
merge beta rc; pr beta ''; eq 'rc' v2.0.0-rc.1 "$(next rc rc)"; git tag v2.0.0-rc.1
merge rc main; pr rc ''; eq 'stable' v2.0.0 "$(next stable main)"; git tag v2.0.0
eq 'same tree all the way' "$(git rev-parse 'alpha^{tree}')" "$(git rev-parse 'main^{tree}')"

git checkout -q alpha; commit d2; pr docs/y release:none
eq 'alpha has nothing after stable' '' "$(next alpha alpha)"
commit f3; pr feat/c release:patch
eq 'patch' v2.0.1-alpha.1 "$(next alpha alpha)"; git tag v2.0.1-alpha.1
commit f4; pr feat/d release:minor
eq 'a higher label raises the version' v2.1.0-alpha.1 "$(next alpha alpha)"; git tag v2.1.0-alpha.1

git checkout -q main; commit h1; pr hotfix/h release:patch
eq 'hotfix' v2.0.1 "$(next stable main)"; git tag v2.0.1
merge main alpha; pr backmerge/beta-to-alpha ''
eq 'back-merged hotfix is released on alpha' v2.1.0-alpha.2 "$(next alpha alpha)"; git tag v2.1.0-alpha.2
git checkout -q alpha; commit f5; pr feat/e release:major
eq 'major' v3.0.0-alpha.1 "$(next alpha alpha)"; git tag v3.0.0-alpha.1
commit f6; pr feat/f release:minor
eq 'minor under a pending major' v3.0.0-alpha.2 "$(next alpha alpha)"

check() {
  local got=ok
  BASE=$2 HEAD=$3 SAME_REPO=$4 LABELS=$5 "$here/check-pr.sh" >/dev/null || got=no
  eq "policy: $3 to $2 (${5:-no label})" "$1" "$got"
}
check ok alpha feat/x true release:minor
check no alpha feat/x true ''
check no alpha feat/x true $'release:minor\nrelease:patch'
check ok alpha feat/x false release:patch
check ok beta alpha true ''
check no beta alpha false ''
check no beta feat/x true release:minor
check ok rc fix/x true release:patch
check ok rc backmerge/main-to-rc true ''
check ok main rc true ''
check no main beta true ''
check no main ci/x true release:none
check ok main hotfix/x true release:patch
