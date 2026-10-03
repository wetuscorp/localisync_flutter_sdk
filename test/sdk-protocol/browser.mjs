import { chromium, firefox, webkit } from '@playwright/test'
import { createServer } from 'node:http'
import { readFile } from 'node:fs/promises'
import { randomUUID, createHash } from 'node:crypto'
import { resolve } from 'node:path'

const fixture = JSON.parse(await readFile(new URL('./delivery.json', import.meta.url), 'utf8'))
const directory = resolve('.local/flutter-browser')
let online = true,
  credentialsLeaked = false
const catalogs = []
function serve(request, response) {
  response.setHeader('Cross-Origin-Opener-Policy', 'same-origin')
  response.setHeader('Cross-Origin-Embedder-Policy', 'require-corp')
  response.setHeader('Cross-Origin-Resource-Policy', 'cross-origin')
  if (request.headers.origin) response.setHeader('Access-Control-Allow-Origin', request.headers.origin)
  response.setHeader('Access-Control-Allow-Headers', 'Authorization, If-None-Match')
  response.setHeader('Access-Control-Expose-Headers', 'ETag')
  if (request.method === 'OPTIONS') {
    response.writeHead(204).end()
    return
  }
  const path = new URL(request.url, 'http://127.0.0.1').pathname
  if (path.startsWith('/delivery/v1/')) {
    if (request.headers.cookie) credentialsLeaked = true
    if (!online) {
      response.writeHead(503).end()
      return
    }
    if (request.headers.authorization !== 'Bearer public-browser-fixture') {
      response.writeHead(401).end()
      return
    }
    const body = path.includes('/files/')
      ? fixture.files[path.split('/').at(-1)]
      : path.includes('/releases/')
        ? fixture.manifestJws
        : fixture.catalogJws
    if (!body) {
      response.writeHead(404).end()
      return
    }
    const etag = '"' + createHash('sha256').update(body).digest('hex') + '"'
    response.setHeader('ETag', etag)
    if (request.headers['if-none-match'] === etag) {
      catalogs.push(304)
      response.writeHead(304).end()
      return
    }
    response.end(body)
    return
  }
  if (path === '/') {
    response.setHeader('Content-Type', 'text/html')
    const wasm = new URL(request.url, 'http://127.0.0.1').searchParams.get('wasm') === 'true'
    response.end(
      '<!doctype html><html lang="en"><head><title>SDK browser acceptance</title></head><body>running' +
        (wasm
          ? '<script type="module">import {compileStreaming} from "/acceptance.mjs"; const app=await compileStreaming(fetch("/acceptance.wasm")); (await app.instantiate({})).invokeMain();</script>'
          : '<script src="/acceptance.js"></script>') +
        '</body></html>'
    )
    return
  }
  if (!['/acceptance.js', '/acceptance.mjs', '/acceptance.wasm'].includes(path)) {
    response.writeHead(404).end()
    return
  }
  response.setHeader('Content-Type', path.endsWith('.wasm') ? 'application/wasm' : 'application/javascript')
  readFile(resolve(directory, path.slice(1)))
    .then(bytes => response.end(bytes))
    .catch(() => response.writeHead(404).end())
}
const servers = [createServer(serve), createServer(serve)]
const addresses = []
for (const server of servers) {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  addresses.push('http://127.0.0.1:' + server.address().port)
}
try {
  const targets = [
    ['Chromium', chromium, {}],
    ['Firefox', firefox, {}],
    ['WebKit', webkit, {}]
  ]
  if (process.env.SDK_TEST_EDGE === 'true') targets.push(['Edge', chromium, { channel: 'msedge' }])
  for (const [name, type, options] of targets) {
    const browser = await type.launch({ headless: true, ...options })
    try {
      for (const wasm of [false, true]) {
        online = true
        const context = await browser.newContext()
        const page = await context.newPage()
        const errors = []
        page.on('pageerror', error => errors.push(error.message))
        const url = new URL(addresses[0])
        url.searchParams.set('id', randomUUID())
        url.searchParams.set('secondary', addresses[1])
        url.searchParams.set('wasm', String(wasm))
        await context.addCookies([{ name: 'sdk-cookie-test', value: 'must-not-send', url: addresses[0] }])
        await page.goto(url.href)
        await page
          .waitForFunction(() => document.body.textContent === 'passed', {}, { timeout: 45000 })
          .catch(error => {
            throw new Error(`${name} ${wasm ? 'Wasm' : 'JS'} failed: ${errors.join('; ')} ${error.message}`)
          })
        online = false
        url.searchParams.set('offline', 'true')
        await page.goto(url.href)
        await page.waitForFunction(() => document.body.textContent === 'passed', {}, { timeout: 45000 })
        await context.close()
        console.info(
          `${name} ${browser.version()} ${wasm ? 'Wasm' : 'JS'}: network, ICU, IndexedDB restart and offline passed.`
        )
      }
    } finally {
      await browser.close()
    }
  }
  if (credentialsLeaked) throw new Error('Delivery fetch sent a cookie.')
  if (!catalogs.includes(304)) throw new Error('ETag revalidation was not exercised.')
} finally {
  for (const server of servers)
    await new Promise(resolve => {
      server.close(resolve)
      server.closeAllConnections()
    })
}
