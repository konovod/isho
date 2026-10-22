#!/usr/bin/env node
// Load probe for the isho stress test.
//
// It measures API and Nuxt SSR response times against whatever data is in the
// database, so it works both before and after db.stress.seed. It finds sample
// stress records through the public API and falls back to the first records it
// sees.
//
//   node stress/probe.mjs
//   node stress/probe.mjs --base http://localhost:3000 --api-base http://localhost:4000 --label local
//   node stress/probe.mjs --base https://example.com --api-base https://example.com --label vps
//
// Results are printed and written to stress/results/<label>-<timestamp>.json.

import fs from 'node:fs'
import path from 'node:path'

const HELP = `
Usage: node stress/probe.mjs [options]

  --base URL          Web/SSR base (default http://localhost:3000)
  --api-base URL      API base (default: the same as --base)
  --label NAME        Result label (default local)
  --runs N            Sequential requests per endpoint (default 7)
  --requests N        Requests per endpoint per concurrency profile (default 10)
  --concurrency LIST  Concurrency profiles, comma separated (default 5,10)
  --timeout SECONDS   Request timeout (default 30)
  --json-out PATH     Result file, or "none" (default stress/results/<label>-<time>.json)
  --help              Show this help
`

const args = parseArgs(process.argv.slice(2))
if (args.help) {
  console.log(HELP.trim())
  process.exit(0)
}

const webBase = trimBase(args.base || 'http://localhost:3000')
const apiBase = trimBase(args['api-base'] || webBase)
const label = String(args.label || 'local')
const runs = positiveInt(args.runs, 7)
const requests = positiveInt(args.requests, 10)
const concurrency = String(args.concurrency || '5,10')
  .split(',')
  .map(value => Number(value.trim()))
  .filter(value => Number.isFinite(value) && value > 1)
const timeoutMs = positiveInt(args.timeout, 30) * 1000
const jsonOut = args['json-out'] === 'none'
  ? null
  : String(args['json-out'] || path.join('stress', 'results', `${label}-${timestamp()}.json`))

if (/\/api(\/|$)/.test(webBase)) {
  console.error('--base must point at the web app, not at /api')
  process.exit(1)
}

console.log(`Probe: ${label}`)
console.log(`  web: ${webBase}`)
console.log(`  api: ${apiBase}`)
console.log(`  runs: ${runs}, requests per profile: ${requests}, concurrency: ${concurrency.join(',') || '(none)'}`)
console.log('')

const fixtures = await discoverFixtures()
const endpoints = buildEndpoints(fixtures)
const startedAt = new Date()

if (endpoints.length === 0) {
  console.error('No endpoints to probe. Is the app running?')
  process.exit(1)
}

const results = []
let totalRequests = 0
let totalErrors = 0

for (const endpoint of endpoints) {
  process.stdout.write(`  ${endpoint.name} ... `)

  const sequential = await measureSequential(endpoint)
  totalRequests += sequential.requests
  totalErrors += sequential.errors
  process.stdout.write(`${formatMs(sequential.p50)} p50, ${formatMs(sequential.p95)} p95`)

  const concurrent = []
  for (const profile of concurrency) {
    const measured = await measureConcurrent(endpoint, profile)
    totalRequests += measured.requests
    totalErrors += measured.errors
    concurrent.push(measured)
    process.stdout.write(`, c${profile} ${formatMs(measured.p95)} p95`)
  }

  process.stdout.write('\n')
  results.push({
    name: endpoint.name,
    kind: endpoint.kind,
    url: endpoint.url,
    sequential,
    concurrent,
  })
}

const finishedAt = new Date()
const payload = {
  label,
  webBase,
  apiBase,
  startedAt: startedAt.toISOString(),
  finishedAt: finishedAt.toISOString(),
  durationSeconds: round((finishedAt - startedAt) / 1000, 2),
  node: process.version,
  runs,
  requests,
  concurrency,
  totals: {
    requests: totalRequests,
    errors: totalErrors,
  },
  fixtures: {
    project: fixtures.project?.slug || null,
    section: fixtures.section?.slug || null,
    topic: fixtures.topic?.slug || null,
    user: fixtures.user || null,
  },
  endpoints: results,
}

console.log('')
printSummary(results, concurrency)
console.log('')
console.log(`Requests: ${totalRequests}, errors: ${totalErrors}`)

if (jsonOut) {
  fs.mkdirSync(path.dirname(jsonOut), { recursive: true })
  fs.writeFileSync(jsonOut, JSON.stringify(payload, null, 2))
  console.log(`Saved: ${jsonOut}`)
}

// ---------------------------------------------------------------------------

async function discoverFixtures() {
  const fixtures = {
    tags: [],
    projects: [],
    sections: [],
    project: null,
    section: null,
    topic: null,
    projectTopic: null,
    projectSection: null,
    user: null,
    catalogTotal: 0,
    catalogPerPage: 24,
    sectionPages: 1,
    projectSectionPages: 1,
    topicLastPage: 1,
  }

  const tags = await tryJson(`${apiBase}/api/v1/tags`)
  fixtures.tags = tags?.items || []

  const catalog = await tryJson(`${apiBase}/api/v1/projects?page=1&per_page=24`)
  if (catalog?.items) {
    fixtures.projects = catalog.items
    fixtures.catalogTotal = catalog.meta?.total || catalog.items.length
    fixtures.catalogPerPage = catalog.meta?.per_page || catalog.items.length || 24
    fixtures.project = catalog.items.find(item => String(item.slug).startsWith('stress-')) || catalog.items[0] || null
    fixtures.user = fixtures.project?.author?.username || null
  }

  const sections = await tryJson(`${apiBase}/api/v1/forum/sections`)
  fixtures.sections = sections?.items || []

  fixtures.section = fixtures.sections.find(section => section.slug === 'gamedesign')
    || fixtures.sections.find(section => section.slug !== 'projects')
    || null

  if (fixtures.section) {
    const data = await tryJson(`${apiBase}/api/v1/forum/sections/${fixtures.section.slug}?page=1`)
    const topics = data?.items || []
    fixtures.topic = topics.find(item => String(item.slug).startsWith('stress-topic-')) || topics[0] || null
    fixtures.sectionPages = data?.meta?.pages || 1
  }

  fixtures.projectSection = fixtures.sections.find(section => section.slug === 'projects') || null
  if (fixtures.projectSection) {
    const data = await tryJson(`${apiBase}/api/v1/forum/sections/projects?page=1`)
    const topics = data?.items || []
    fixtures.projectTopic = topics.find(item => item.project) || null
    fixtures.projectSectionPages = data?.meta?.pages || 1
  }

  if (fixtures.topic) {
    const data = await tryJson(`${apiBase}/api/v1/forum/sections/${fixtures.section.slug}/topics/${fixtures.topic.slug}?page=1`)
    fixtures.topicLastPage = data?.topic?.last_page || data?.meta?.pages || 1
  }

  return fixtures
}

function buildEndpoints(fixtures) {
  const endpoints = []
  const seen = new Set()

  function add(kind, name, url) {
    if (seen.has(name)) return
    seen.add(name)
    endpoints.push({ kind, name, url })
  }

  add('api', 'api health', `${apiBase}/api/v1/health`)
  add('api', 'api tags', `${apiBase}/api/v1/tags`)
  add('api', 'api catalog page 1', `${apiBase}/api/v1/projects?page=1`)
  add('api', 'api catalog search', `${apiBase}/api/v1/projects?q=0001`)

  if (fixtures.catalogTotal > 0) {
    const deep = Math.max(1, Math.ceil(fixtures.catalogTotal / fixtures.catalogPerPage))
    add('api', `api catalog page ${deep}`, `${apiBase}/api/v1/projects?page=${deep}`)
  }

  const tag = fixtures.tags.find(item => String(item.slug).startsWith('stress-teg-')) || fixtures.tags[0]
  if (tag) {
    add('api', 'api catalog by tag', `${apiBase}/api/v1/projects?tag=${encodeURIComponent(tag.slug)}`)
  }

  if (fixtures.project) {
    add('api', 'api project', `${apiBase}/api/v1/projects/${encodeURIComponent(fixtures.project.slug)}`)
  }

  add('api', 'api forum sections', `${apiBase}/api/v1/forum/sections`)

  if (fixtures.section) {
    add('api', 'api forum section page 1', `${apiBase}/api/v1/forum/sections/${fixtures.section.slug}?page=1`)
    if (fixtures.sectionPages > 1) {
      add('api', `api forum section page ${fixtures.sectionPages}`, `${apiBase}/api/v1/forum/sections/${fixtures.section.slug}?page=${fixtures.sectionPages}`)
    }
  }

  if (fixtures.projectSection) {
    add('api', 'api forum projects page 1', `${apiBase}/api/v1/forum/sections/projects?page=1`)
    if (fixtures.projectSectionPages > 1) {
      add('api', `api forum projects page ${fixtures.projectSectionPages}`, `${apiBase}/api/v1/forum/sections/projects?page=${fixtures.projectSectionPages}`)
    }
  }

  if (fixtures.topic && fixtures.section) {
    const base = `${apiBase}/api/v1/forum/sections/${fixtures.section.slug}/topics/${fixtures.topic.slug}`
    add('api', 'api topic page 1', `${base}?page=1`)
    if (fixtures.topicLastPage > 1) {
      add('api', `api topic page ${fixtures.topicLastPage}`, `${base}?page=${fixtures.topicLastPage}`)
    }
  }

  if (fixtures.projectTopic && fixtures.projectSection) {
    add('api', 'api project topic', `${apiBase}/api/v1/forum/sections/projects/topics/${fixtures.projectTopic.slug}?page=1`)
  }

  if (fixtures.user) {
    add('api', 'api profile', `${apiBase}/api/v1/users/${encodeURIComponent(fixtures.user)}`)
  }

  // SSR pages go through Nuxt and, in production, through Caddy as well.
  add('web', 'ssr home', `${webBase}/`)
  add('web', 'ssr forum', `${webBase}/forum`)

  if (fixtures.section) {
    add('web', 'ssr forum section', `${webBase}/forum/${fixtures.section.slug}`)
  }

  if (fixtures.topic && fixtures.section) {
    add('web', 'ssr topic', `${webBase}/forum/${fixtures.section.slug}/${fixtures.topic.slug}`)
  }

  if (fixtures.project) {
    add('web', 'ssr project', `${webBase}/p/${fixtures.project.slug}`)
  }

  if (fixtures.user) {
    add('web', 'ssr profile', `${webBase}/u/${fixtures.user}`)
  }

  return endpoints
}

async function measureSequential(endpoint) {
  await timed(endpoint) // warm up
  const samples = []
  for (let i = 0; i < runs; i++) {
    samples.push(await timed(endpoint))
  }
  return summarize(samples)
}

async function measureConcurrent(endpoint, profile) {
  const total = Math.max(profile, requests)
  const started = performance.now()
  const samples = await pool(total, profile, () => timed(endpoint))
  const wallMs = performance.now() - started
  const summary = summarize(samples)
  summary.concurrency = profile
  summary.wallMs = round(wallMs, 1)
  summary.rps = wallMs > 0 ? round(total / (wallMs / 1000), 1) : 0
  return summary
}

async function timed(endpoint) {
  const started = performance.now()
  try {
    const response = await fetch(endpoint.url, {
      headers: {
        accept: endpoint.kind === 'api' ? 'application/json' : 'text/html',
        'user-agent': 'isho-stress-probe',
      },
      signal: AbortSignal.timeout(timeoutMs),
    })
    const body = await response.arrayBuffer()
    return {
      ok: response.ok,
      status: response.status,
      ms: performance.now() - started,
      bytes: body.byteLength,
    }
  } catch (error) {
    return {
      ok: false,
      status: 0,
      ms: performance.now() - started,
      bytes: 0,
      error: error?.name === 'TimeoutError' ? 'timeout' : String(error?.message || error),
    }
  }
}

function summarize(samples) {
  const ok = samples.filter(sample => sample.ok)
  const times = ok.map(sample => sample.ms).sort((a, b) => a - b)
  const bytes = ok.map(sample => sample.bytes)
  const failures = samples.filter(sample => !sample.ok)
  const statuses = {}
  for (const sample of samples) {
    statuses[sample.status] = (statuses[sample.status] || 0) + 1
  }

  return {
    requests: samples.length,
    ok: ok.length,
    errors: failures.length,
    statuses,
    p50: round(percentile(times, 0.5), 1),
    p95: round(percentile(times, 0.95), 1),
    p99: round(percentile(times, 0.99), 1),
    min: round(times[0] || 0, 1),
    max: round(times[times.length - 1] || 0, 1),
    avgMs: round(average(times), 1),
    avgBytes: Math.round(average(bytes)),
    firstError: failures[0]?.error || (failures[0] ? `HTTP ${failures[0].status}` : null),
  }
}

function percentile(values, p) {
  if (values.length === 0) return 0
  const index = Math.min(values.length - 1, Math.max(0, Math.ceil(p * values.length) - 1))
  return values[index]
}

function average(values) {
  if (values.length === 0) return 0
  return values.reduce((sum, value) => sum + value, 0) / values.length
}

async function pool(total, limit, task) {
  const results = new Array(total)
  let next = 0
  const workers = Array.from({ length: Math.min(limit, total) }, async () => {
    while (true) {
      const index = next++
      if (index >= total) return
      results[index] = await task()
    }
  })
  await Promise.all(workers)
  return results
}

function printSummary(results, profiles) {
  console.log('Sequential')
  console.log(`  ${pad('endpoint', 30)} ${pad('n', 4)} ${pad('p50', 8)} ${pad('p95', 8)} ${pad('max', 8)} ${pad('err', 4)} ${pad('KB', 7)}`)
  for (const result of results) {
    const summary = result.sequential
    console.log(`  ${pad(result.name, 30)} ${pad(summary.requests, 4)} ${pad(formatMs(summary.p50), 8)} ${pad(formatMs(summary.p95), 8)} ${pad(formatMs(summary.max), 8)} ${pad(summary.errors, 4)} ${pad((summary.avgBytes / 1024).toFixed(1), 7)}`)
    if (summary.firstError) {
      console.log(`    ! ${summary.firstError}`)
    }
  }

  for (const profile of profiles) {
    console.log('')
    console.log(`Concurrency ${profile}`)
    console.log(`  ${pad('endpoint', 30)} ${pad('p50', 8)} ${pad('p95', 8)} ${pad('err', 4)} ${pad('rps', 8)}`)
    for (const result of results) {
      const summary = result.concurrent.find(item => item.concurrency === profile)
      if (!summary) continue
      console.log(`  ${pad(result.name, 30)} ${pad(formatMs(summary.p50), 8)} ${pad(formatMs(summary.p95), 8)} ${pad(summary.errors, 4)} ${pad(summary.rps.toFixed(1), 8)}`)
      if (summary.firstError) {
        console.log(`    ! ${summary.firstError}`)
      }
    }
  }
}

async function tryJson(url) {
  try {
    const response = await fetch(url, {
      headers: { accept: 'application/json', 'user-agent': 'isho-stress-probe' },
      signal: AbortSignal.timeout(timeoutMs),
    })
    if (!response.ok) return null
    return await response.json()
  } catch {
    return null
  }
}

function parseArgs(argv) {
  const parsed = {}
  for (let i = 0; i < argv.length; i++) {
    const argument = argv[i]
    if (!argument.startsWith('--')) continue

    const equals = argument.indexOf('=')
    if (equals !== -1) {
      parsed[argument.slice(2, equals)] = argument.slice(equals + 1)
      continue
    }

    const key = argument.slice(2)
    const next = argv[i + 1]
    if (next && !next.startsWith('--')) {
      parsed[key] = next
      i++
    } else {
      parsed[key] = true
    }
  }
  return parsed
}

function positiveInt(value, fallback) {
  const parsed = Number(value)
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : fallback
}

function trimBase(value) {
  return String(value).replace(/\/+$/, '')
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
}

function pad(value, width) {
  return String(value).padEnd(width)
}

function formatMs(value) {
  return `${Number(value).toFixed(0)}ms`
}

function round(value, digits) {
  const factor = 10 ** digits
  return Math.round(value * factor) / factor
}
