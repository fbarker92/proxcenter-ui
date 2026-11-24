// ProxCenter version.
//
// A release stamps PROXCENTER_VERSION and PROXCENTER_COMMIT on an image CI has
// already built and tested, so both are read when the container runs, not
// inlined by the build. The browser has no environment: the root layout puts
// the same two values on <html> (data-app-version, data-git-sha). Without them
// the build-time NEXT_PUBLIC_* values apply, then package.json (`npm run dev`).
import pkg from '../../package.json'

const injected = typeof document === 'undefined' ? undefined : document.documentElement?.dataset

export const VERSION_NAME = 'ProxCenter'
export const APP_VERSION =
  injected?.appVersion || process.env.PROXCENTER_VERSION || process.env.NEXT_PUBLIC_APP_VERSION || pkg.version
export const GIT_SHA =
  injected?.gitSha || process.env.PROXCENTER_COMMIT || process.env.NEXT_PUBLIC_GIT_SHA || ''
export const GITHUB_REPO = 'fbarker92/proxcenter-ui'
export const GITHUB_URL = `https://github.com/${GITHUB_REPO}`
