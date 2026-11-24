# Releasing

This fork builds one image, `ghcr.io/fbarker92/proxcenter-frontend` (Community Edition, amd64).

## Stages

```
feature branch → alpha → beta → rc → main
```

| Branch  | Released as      | Image tags                      | Accepts pull requests from                  |
| ------- | ---------------- | ------------------------------- | ------------------------------------------- |
| `alpha` | `vX.Y.Z-alpha.N` | `X.Y.Z-alpha.N`, `alpha`        | any branch                                  |
| `beta`  | `vX.Y.Z-beta.N`  | `X.Y.Z-beta.N`, `beta`          | `alpha`, `fix/*`, `hotfix/*`, back-merges   |
| `rc`    | `vX.Y.Z-rc.N`    | `X.Y.Z-rc.N`, `rc`              | `beta`, `fix/*`, `hotfix/*`, back-merges    |
| `main`  | `vX.Y.Z`         | `X.Y.Z`, `X.Y`, `X`, `latest`   | `rc`, `hotfix/*`                            |

Promote by opening a pull request from one stage to the next. Everything merges with a **merge
commit**: a squash would break the version calculation and the next upstream sync.

## Versions

Each pull request carries exactly one label:

| Label           | For                                             |
| --------------- | ----------------------------------------------- |
| `release:major` | a release of many new features                  |
| `release:minor` | a handful of features                           |
| `release:patch` | fixes to existing features                      |
| `release:none`  | no release: documentation, CI, tests            |

The version is the last stable release raised by the highest label merged since. Labels do not add
up: three `release:minor` pull requests are one minor. The first stable release is 2.0.0 whatever
its labels. Promotions and back-merges need no label. A merge holding only `release:none` changes
publishes nothing.

Set the label before merging. `frontend/package.json` keeps upstream's version, and release notes
quote it as the base.

## Images are built once

A pull request tests and builds the merge GitHub previews. When everything passes, the image is
stored in `proxcenter-frontend-ci` under the git tree it was built from. The merge produces the same
tree, so CI only adds the version to that image and publishes it. The same image is promoted all
the way to `main` as long as the code does not change.

The merge takes a full run instead when the stored image is missing: the base moved in between, the
pull request came from a fork or Dependabot (read-only token), or the image is over 30 days old.

## Fixes

- Found on `beta` or `rc`: a `fix/*` branch from that stage, merged back into it.
- Found in a stable release: a `hotfix/*` branch from `main`, merged into `main`.

CI then opens back-merge pull requests (`main` → `rc` → `beta` → `alpha`), one stage at a time.
Merge each one to start the next.

## Upstream

Every Monday, CI opens a pull request merging upstream's `main` into `alpha`, labelled
`release:patch`; raise the label if upstream added features. Files this fork deleted
(`.github/fork-removed-files.txt`) stay deleted. Other conflicts are listed in the pull request.

## The automation token

The sync and back-merge jobs need the repository secret `AUTOMATION_TOKEN`: a fine-grained personal
access token limited to this repository, with read and write access to **Contents**,
**Pull requests** and **Workflows**. Releases use it too when it is set. Renew it before it expires.

## Enterprise and HA

The Enterprise, HA and air-gap files point to this fork's registry like the rest, but the
orchestrator is closed source, and WeasyPrint and the HA images are not built here. Those
installations need `REGISTRY=ghcr.io/adminsyspro` and upstream's images.
