import { createPrivateKey, createPublicKey } from 'node:crypto'
import { mkdir, writeFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { sign, digest } from '../../packages/delivery-protocol/dist/crypto.js'
import { localeFileSchema, releaseManifestSchema, catalogSchema } from '../../packages/delivery-protocol/dist/index.js'

// Public deterministic acceptance seed, never a production signing identity.
const privateKey = createPrivateKey({
  key: Buffer.concat([Buffer.from('302e020100300506032b657004220420', 'hex'), Buffer.alloc(32, 7)]),
  format: 'der',
  type: 'pkcs8'
})
  .export({ format: 'pem', type: 'pkcs8' })
  .toString()
const publicKey = createPublicKey(privateKey).export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64')
const output = resolve(process.argv[2] ?? '.local/flutter-performance-fixtures')
const projectId = '10000000-0000-4000-8000-000000000001'
const distributionId = '20000000-0000-4000-8000-000000000001'
const releaseId = '30000000-0000-4000-8000-000000000001'
const compatibility = { min: null, max: null }
for (const profile of ['small', 'icu', 'long']) {
  const locales = profile === 'small' ? ['en', 'tr'] : ['en', 'tr', 'fr', 'de', 'ar']
  const count = profile === 'small' ? 10 : 10000
  const directory = resolve(output, profile)
  await mkdir(directory, { recursive: true })
  const files = []
  for (const locale of locales) {
    const entries = Array.from({ length: count }, (_, index) => {
      const icu = index === 0 || (profile === 'icu' && index !== 1)
      return {
        key: `key_${index}`,
        format: icu ? 'icu' : 'plain',
        parameters: icu ? [{ name: 'count', type: 'number' }] : [],
        value: icu
          ? '{count, plural, one {# item} other {# items}}'
          : profile === 'long'
            ? 'a'.repeat(1900)
            : 'Published text'
      }
    })
    const body = JSON.stringify(localeFileSchema.parse({ protocol: 1, releaseId, locale, entries }))
    files.push({ locale, digest: digest(body), bytes: Buffer.byteLength(body) })
    await writeFile(resolve(directory, `${locale}.json`), body)
  }
  const manifest = releaseManifestSchema.parse({
    protocol: 1,
    kind: 'release',
    projectId,
    releaseId,
    compatibility,
    requestedLocales: locales,
    languages: locales.map((locale, index) => ({ locale, fallback: index === 0 ? null : locales[index - 1] })),
    files,
    keyCount: count
  })
  const manifestJws = await sign(manifest, privateKey, 'test-1')
  const catalogJws = await sign(
    catalogSchema.parse({
      protocol: 1,
      kind: 'catalog',
      projectId,
      distributionId,
      channel: 'preview',
      revision: 1,
      publications: [
        {
          id: '40000000-0000-4000-8000-000000000001',
          releaseId,
          sequence: 1,
          manifestDigest: digest(manifestJws),
          compatibility
        }
      ]
    }),
    privateKey,
    'test-1'
  )
  const bytes = files.reduce((sum, file) => sum + file.bytes, 0)
  if (bytes > 100 * 1024 * 1024) throw new Error('Performance fixture exceeds delivery limit.')
  await writeFile(
    resolve(directory, 'index.json'),
    JSON.stringify({
      profile,
      publicKey,
      projectId,
      distributionId,
      manifestJws,
      catalogJws,
      files,
      keys: count,
      values: count * locales.length,
      bytes,
      locale: locales.at(-1)
    })
  )
  console.info(JSON.stringify({ profile, keys: count, values: count * locales.length, bytes }))
}
