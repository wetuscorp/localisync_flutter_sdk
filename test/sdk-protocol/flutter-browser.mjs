import assert from 'node:assert/strict'
import { createServer } from 'node:http'
import { readFile, mkdir, writeFile } from 'node:fs/promises'
import { resolve, extname, sep } from 'node:path'
import { randomUUID } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { chromium, firefox, webkit } from '@playwright/test'

const fixture = JSON.parse(await readFile(new URL('./delivery.json', import.meta.url), 'utf8'))
const output = resolve('.local/flutter-validation')
await mkdir(output, { recursive: true })
let directory,
  online = true,
  primaryOffline = false,
  requests = 0,
  leakedCookie = false
const servers = [],
  addresses = []
for (let i = 0; i < 2; i++) {
  const server = createServer(async (req, res) => {
    try {
      res.setHeader('Cross-Origin-Opener-Policy', 'same-origin')
      res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp')
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin')
      if (req.headers.origin === addresses[0] && req.url !== '/cors-denied')
        res.setHeader('Access-Control-Allow-Origin', addresses[0])
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, If-None-Match')
      if (req.method === 'OPTIONS') return res.writeHead(204).end()
      const path = new URL(req.url, 'http://127.0.0.1').pathname
      if (path.startsWith('/delivery/v1/')) {
        requests++
        if (req.headers.cookie) leakedCookie = true
        if (!online || (i === 0 && primaryOffline)) return res.writeHead(503).end()
        if (req.headers.authorization !== 'Bearer public-browser-fixture') return res.writeHead(401).end()
        const body = path.includes('/files/')
          ? fixture.files[path.split('/').at(-1)]
          : path.includes('/releases/')
            ? fixture.manifestJws
            : fixture.catalogJws
        if (!body) return res.writeHead(404).end()
        return res.end(body)
      }
      const file = resolve(directory, '.' + (path === '/' ? '/index.html' : path))
      if (!file.startsWith(directory + sep)) return res.writeHead(404).end()
      const types = {
        '.html': 'text/html',
        '.js': 'application/javascript',
        '.mjs': 'application/javascript',
        '.wasm': 'application/wasm',
        '.json': 'application/json',
        '.ttf': 'font/ttf'
      }
      res.setHeader('Content-Type', types[extname(file)] ?? 'application/octet-stream')
      res.end(await readFile(file))
    } catch {
      res.writeHead(404).end()
    }
  })
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  servers.push(server)
  addresses.push(`http://127.0.0.1:${server.address().port}`)
}

class SafariPage {
  constructor(session) {
    this.session = session
  }
  async call(method, path, body) {
    const response = await fetch(
      `http://127.0.0.1:${process.env.SDK_SAFARI_PORT ?? 4447}/session${this.session ? '/' + this.session : ''}${path}`,
      {
        method,
        headers: { 'Content-Type': 'application/json' },
        ...(body ? { body: JSON.stringify(body) } : {}),
        signal: AbortSignal.timeout(65000)
      }
    )
    const data = await response.json()
    if (!response.ok || data.value?.error) throw new Error(JSON.stringify(data.value))
    return data.value
  }
  async goto(url) {
    await this.call('POST', '/url', { url })
  }
  async evaluate(expression) {
    const result = await this.call('POST', '/execute/async', {
      script: `const done=arguments[arguments.length-1]; Promise.resolve().then(()=>(${expression})).then(done,e=>done({acceptanceError:String(e)}));`,
      args: []
    })
    if (result?.acceptanceError) throw new Error(result.acceptanceError)
    return result
  }
  async pointerClick(id) {
    const rect = await this.call('GET', `/element/${id}/rect`)
    await this.call('POST', '/actions', {
      actions: [
        {
          type: 'pointer',
          id: 'mouse',
          parameters: { pointerType: 'mouse' },
          actions: [
            {
              type: 'pointerMove',
              duration: 0,
              origin: 'viewport',
              x: Math.round(rect.x + rect.width / 2),
              y: Math.round(rect.y + rect.height / 3)
            },
            { type: 'pointerDown', button: 0 },
            { type: 'pointerUp', button: 0 }
          ]
        }
      ]
    })
  }
  async click(label) {
    const element = await this.call('POST', '/element', {
      using: 'xpath',
      value: `//*[@role="button" and (@aria-label="${label}" or normalize-space(.)="${label}")]`
    })
    await this.evaluate('new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))')
    await this.call('POST', `/element/${Object.values(element)[0]}/click`, {})
  }
  async focusDraft() {
    const element = await this.call('POST', '/element', {
      using: 'css selector',
      value: 'input[aria-label="Your draft"]'
    })
    await this.pointerClick(Object.values(element)[0])
  }
  async fill(text) {
    const element = await this.call('POST', '/element', {
      using: 'css selector',
      value: 'input[aria-label="Your draft"]'
    })
    await this.pointerClick(Object.values(element)[0])
    await this.evaluate('new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))')
    const active = await this.call('GET', '/element/active')
    await this.call('POST', `/element/${Object.values(active)[0]}/value`, { text })
  }
  async screenshot(path) {
    await writeFile(path, Buffer.from(await this.call('GET', '/screenshot'), 'base64'))
  }
  async close() {
    await this.call('DELETE', '')
  }
  async openPeer(url) {
    const original = await this.call('GET', '/window')
    const tab = await this.call('POST', '/window/new', { type: 'tab' })
    await this.call('POST', '/window', { handle: tab.handle })
    const peer = new SafariPage(this.session)
    await peer.goto(url)
    peer.close = async () => {
      await peer.call('DELETE', '/window')
      await this.call('POST', '/window', { handle: original })
    }
    return peer
  }
}
async function wait(read, predicate, label) {
  const deadline = Date.now() + 45000
  let result
  while (Date.now() < deadline) {
    try {
      result = await read()
      if (predicate(result)) return result
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 100))
  }
  throw new Error(`Timed out: ${label}; last result ${JSON.stringify(result)}`)
}
const results = []
try {
  const names = (process.env.SDK_BROWSER_TARGETS ?? 'chromium,firefox,webkit').split(',')
  for (const name of names) {
    let browser, context, page, version
    if (name === 'safari') {
      await wait(
        async () => {
          const response = await fetch('http://127.0.0.1:4447/status', { signal: AbortSignal.timeout(1000) })
          if (!response.ok) throw new Error(`Safari driver status: ${response.status}`)
          return response.json()
        },
        value => value.value?.ready === true,
        'Safari WebDriver readiness'
      )
      const initial = new SafariPage('')
      const data = await initial.call('POST', '', { capabilities: { alwaysMatch: { browserName: 'safari' } } })
      page = new SafariPage(data.sessionId)
      version = data.capabilities.browserVersion
      await page.call('POST', '/timeouts', { script: 45000, pageLoad: 45000, implicit: 1000 })
    } else {
      const type = { chromium, chrome: chromium, edge: chromium, firefox, webkit }[name]
      browser = await type.launch({
        headless: true,
        ...(['chrome', 'edge'].includes(name) ? { channel: name === 'edge' ? 'msedge' : 'chrome' } : {})
      })
      version = browser.version()
      context = await browser.newContext()
      const actual = await context.newPage()
      page = {
        goto: url => actual.goto(url),
        evaluate: expr => actual.evaluate(expr),
        click: text => actual.getByRole('button', { name: text, exact: true }).click(),
        fill: async text => {
          await actual.getByRole('textbox').click()
          await actual.evaluate(
            () => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
          )
          await actual.keyboard.insertText(text)
        },
        focusDraft: () => actual.getByRole('textbox').click(),
        screenshot: path => actual.screenshot({ path }),
        close: () => context.close()
      }
    }
    try {
      for (const example of ['basic', 'gen_l10n'])
        for (const build of ['js', 'wasm']) {
          directory = resolve(`.local/flutter-web/${example}/${build}`)
          online = true
          primaryOffline = false
          const id = randomUUID(),
            url = `${addresses[0]}/?id=${id}&secondary=${encodeURIComponent(addresses[1])}`
          await page.goto(url)
          await wait(
            () => page.evaluate('typeof window.localisyncStatus'),
            value => value === 'function',
            'Flutter bootstrap'
          )
          const command = async value =>
            JSON.parse(await page.evaluate(`window.localisyncCommand(${JSON.stringify(value)})`))
          const status = async () => JSON.parse(await page.evaluate('window.localisyncStatus()'))
          let state = await command('ready')
          await page.evaluate('document.cookie="acceptance=present; SameSite=Lax"')
          assert(await page.evaluate('document.cookie.includes("acceptance=present")'))
          assert(
            await page.evaluate(
              `fetch(${JSON.stringify(addresses[1] + '/cors-denied')}, {headers:{Authorization:'Bearer public-browser-fixture'},credentials:'omit'}).then(()=>false,()=>true)`
            )
          )
          const before = requests
          await page.fill('Keep browser draft')
          await wait(status, value => value.draft === 'Keep browser draft', 'initial draft entry')
          primaryOffline = true
          await page.click('Check for updates')
          await wait(status, value => value.pending, 'manual update')
          await page.click('Activate update')
          state = await wait(status, value => value.plain === 'Published text', 'activation')
          assert.equal(state.rank, '22nd')
          assert(requests > before)
          assert.equal(state.persisted, true)
          if (build === 'js') assert.equal(state.runtime, 'js')
          if (build === 'wasm' && ['chrome', 'chromium', 'edge'].includes(name)) assert.equal(state.runtime, 'wasm')
          await command('tr')
          assert.equal((await status()).greeting, 'Merhaba Developer')
          await command('en')
          await page.click('Open another screen')
          await command('refresh')
          await wait(
            () =>
              page.evaluate(
                'document.body.textContent.includes("Preserved route") || Array.from(document.querySelectorAll("[aria-label]")).some(e=>e.getAttribute("aria-label").includes("Preserved route"))'
              ),
            value => value,
            'preserved route'
          )
          // Back remains a real Flutter navigation action, not a re-created application.
          await page.click('Back')
          await page.focusDraft()
          await wait(status, value => value.draft === 'Keep browser draft', 'preserved draft')
          await page.screenshot(resolve(output, `${name}-${example}-${build}.png`))
          // Two actual tabs share IndexedDB, but retain independent Flutter state.
          await page.evaluate("(window.acceptanceRefresh=window.localisyncCommand('refresh'), true)")
          const peer = context ? await context.newPage() : await page.openPeer(url)
          try {
            if (context) await peer.goto(url)
            await wait(
              () => peer.evaluate('typeof window.localisyncStatus'),
              value => value === 'function',
              'second tab bootstrap'
            )
            const second = JSON.parse(await peer.evaluate("window.localisyncCommand('ready')"))
            assert.equal(second.plain, 'Published text')
            assert.equal(second.draft, '')
            assert.equal(JSON.parse(await peer.evaluate("window.localisyncCommand('refresh')")).plain, 'Published text')
          } finally {
            await peer.close()
          }
          await page.evaluate('window.acceptanceRefresh')
          assert.equal((await status()).draft, 'Keep browser draft')
          online = false
          await page.goto(url)
          await wait(
            () => page.evaluate('typeof window.localisyncStatus'),
            value => value === 'function',
            'offline application bootstrap'
          )
          state = await command('ready')
          assert.equal(state.plain, 'Published text')
          assert.equal(state.persisted, true)
          assert.equal((await command('refresh')).plain, 'Published text')
          results.push({ browser: name, version, example, build, runtime: state.runtime, outcome: 'passed' })
          console.info(JSON.stringify(results.at(-1)))
        }
    } catch (error) {
      await page.screenshot(resolve(output, `${name}-failure.png`))
      await writeFile(resolve(output, `${name}-failure-dom.html`), await page.evaluate('document.body.innerHTML'))
      throw error
    } finally {
      await page.close()
      await browser?.close()
    }
  }
  assert.equal(leakedCookie, false)
} finally {
  await writeFile(
    resolve(output, 'flutter-browsers.json'),
    JSON.stringify(
      { commit: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(), results },
      null,
      2
    )
  )
  for (const server of servers)
    await new Promise(resolve => {
      server.close(resolve)
      server.closeAllConnections()
    })
}
