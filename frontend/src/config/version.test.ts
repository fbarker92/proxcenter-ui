import { afterEach, describe, expect, it, vi } from 'vitest'

import pkg from '../../package.json'

const load = async () => {
  vi.resetModules()

  return import('./version')
}

describe('version', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
    vi.unstubAllGlobals()
  })

  it('reads the release stamp at run time, before the value of the build', async () => {
    vi.stubEnv('NEXT_PUBLIC_APP_VERSION', 'dev')
    vi.stubEnv('PROXCENTER_VERSION', '2.0.0-alpha.1')
    vi.stubEnv('PROXCENTER_COMMIT', 'abc1234')
    expect(await load()).toMatchObject({ APP_VERSION: '2.0.0-alpha.1', GIT_SHA: 'abc1234' })
  })

  it('reads what the root layout put on <html> in the browser', async () => {
    vi.stubGlobal('document', { documentElement: { dataset: { appVersion: '2.1.0', gitSha: 'def5678' } } })
    expect(await load()).toMatchObject({ APP_VERSION: '2.1.0', GIT_SHA: 'def5678' })
  })

  it('falls back to the build, then to package.json', async () => {
    vi.stubEnv('PROXCENTER_VERSION', '')
    vi.stubEnv('NEXT_PUBLIC_APP_VERSION', 'dev')
    expect((await load()).APP_VERSION).toBe('dev')
    vi.stubEnv('NEXT_PUBLIC_APP_VERSION', '')
    expect((await load()).APP_VERSION).toBe(pkg.version)
  })
})
