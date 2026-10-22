import MarkdownIt from 'markdown-it'
import container from 'markdown-it-container'
import hljs from 'highlight.js/lib/core'
import bash from 'highlight.js/lib/languages/bash'
import c from 'highlight.js/lib/languages/c'
import cpp from 'highlight.js/lib/languages/cpp'
import csharp from 'highlight.js/lib/languages/csharp'
import css from 'highlight.js/lib/languages/css'
import crystal from 'highlight.js/lib/languages/crystal'
import diff from 'highlight.js/lib/languages/diff'
import go from 'highlight.js/lib/languages/go'
import ini from 'highlight.js/lib/languages/ini'
import java from 'highlight.js/lib/languages/java'
import javascript from 'highlight.js/lib/languages/javascript'
import json from 'highlight.js/lib/languages/json'
import kotlin from 'highlight.js/lib/languages/kotlin'
import lua from 'highlight.js/lib/languages/lua'
import markdown from 'highlight.js/lib/languages/markdown'
import php from 'highlight.js/lib/languages/php'
import plaintext from 'highlight.js/lib/languages/plaintext'
import powershell from 'highlight.js/lib/languages/powershell'
import python from 'highlight.js/lib/languages/python'
import ruby from 'highlight.js/lib/languages/ruby'
import rust from 'highlight.js/lib/languages/rust'
import sql from 'highlight.js/lib/languages/sql'
import typescript from 'highlight.js/lib/languages/typescript'
import xml from 'highlight.js/lib/languages/xml'
import yaml from 'highlight.js/lib/languages/yaml'

/** Devlogs longer than this are previewed on the project page with a link. */
export const DEVLOG_INLINE_MAX_CHARS = 600

// Only the languages a game-dev showcase is likely to use; the full
// highlight.js bundle is an order of magnitude larger.
for (const [name, language] of Object.entries({
  bash,
  c,
  cpp,
  csharp,
  css,
  crystal,
  diff,
  go,
  ini,
  java,
  javascript,
  json,
  kotlin,
  lua,
  markdown,
  php,
  plaintext,
  powershell,
  python,
  ruby,
  rust,
  sql,
  typescript,
  xml,
  yaml,
})) {
  hljs.registerLanguage(name, language)
}

// Highlighting very long fences would block SSR for little benefit.
const MAX_HIGHLIGHT_CHARS = 20_000

const md = new MarkdownIt({
  html: false,
  linkify: true,
  breaks: true,
})

// External links open in a new tab; markdown-it already blocks unsafe protocols.
const defaultLinkOpen = md.renderer.rules.link_open
  ?? ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))

md.renderer.rules.link_open = (tokens, idx, options, env, self) => {
  const token = tokens[idx]!
  const href = String(token.attrGet('href') ?? '')

  if (/^https?:\/\//i.test(href)) {
    token.attrSet('target', '_blank')
    token.attrSet('rel', 'noopener noreferrer nofollow')
  }

  return defaultLinkOpen(tokens, idx, options, env, self)
}

const RUTUBE_HOSTS = new Set(['rutube.ru', 'www.rutube.ru', 'm.rutube.ru'])
const RUTUBE_ID = /^[0-9a-f]{32}$/i
const RUTUBE_PATH = /^\/(?:video|play\/embed)\/(?:private\/)?([0-9a-f]{32})\/?$/i

/**
 * Turns a Rutube video URL (or bare ID) into its embed URL. Returns null for
 * everything else, so the same `![alt](url)` syntax still renders images.
 */
export function rutubeEmbedUrl(value?: string | null): string | null {
  if (!value) return null

  const raw = value.trim()

  if (RUTUBE_ID.test(raw)) return `https://rutube.ru/play/embed/${raw.toLowerCase()}/`

  let url: URL

  try {
    url = new URL(raw.startsWith('//') ? `https:${raw}` : raw)
  }
  catch {
    return null
  }

  if (url.protocol !== 'http:' && url.protocol !== 'https:') return null
  if (!RUTUBE_HOSTS.has(url.hostname.toLowerCase())) return null

  const match = url.pathname.match(RUTUBE_PATH)
  if (!match) return null

  // Private videos carry their access key in `p`; keep it on the embed URL.
  const key = url.searchParams.get('p')
  const suffix = key ? `?p=${encodeURIComponent(key)}` : ''

  return `https://rutube.ru/play/embed/${match[1]!.toLowerCase()}/${suffix}`
}

const defaultImage = md.renderer.rules.image
  ?? ((tokens, idx, options, _env, self) => self.renderToken(tokens, idx, options))

md.renderer.rules.image = (tokens, idx, options, env, self) => {
  const token = tokens[idx]!
  const src = String(token.attrGet('src') ?? '')
  const embed = rutubeEmbedUrl(src)

  if (embed) {
    const title = token.content.trim() || 'Видео Rutube'

    return `<span class="md-video"><iframe src="${md.utils.escapeHtml(embed)}" title="${md.utils.escapeHtml(title)}" loading="lazy" allow="autoplay; fullscreen; picture-in-picture; clipboard-write" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe></span>`
  }

  token.attrSet('loading', 'lazy')
  token.attrSet('decoding', 'async')

  return defaultImage(tokens, idx, options, env, self)
}

md.use(container, 'spoiler', {
  validate: params => /^spoiler(?:\s|$)/.test(params.trim()),
  render: (tokens: { nesting: number, info: string }[], idx: number) => {
    const token = tokens[idx]!

    if (token.nesting === 1) {
      const title = token.info.trim().replace(/^spoiler\s*/, '').trim()
      const label = title ? md.utils.escapeHtml(title) : 'Спойлер'

      return `<details class="md-spoiler"><summary>${label}</summary><div class="md-spoiler-body">\n`
    }

    return '</div></details>\n'
  },
})

md.renderer.rules.fence = (tokens, idx) => {
  const token = tokens[idx]!
  const info = token.info.trim()
  const requested = info.split(/\s+/)[0]?.replace(/^language-/, '') ?? ''
  const language = requested && hljs.getLanguage(requested) ? requested : ''
  const code = token.content

  if (!language || code.length > MAX_HIGHLIGHT_CHARS) {
    return `<pre><code>${md.utils.escapeHtml(code)}</code></pre>\n`
  }

  let highlighted: string

  try {
    highlighted = hljs.highlight(code, { language, ignoreIllegals: true }).value
  }
  catch {
    return `<pre><code>${md.utils.escapeHtml(code)}</code></pre>\n`
  }

  return `<pre><code class="hljs language-${md.utils.escapeHtml(language)}">${highlighted}</code></pre>\n`
}

// Forum pages render the same posts over and over. The cache lives for the
// lifetime of the SSR process (or browser tab); keep it small and bounded so
// user-generated text cannot grow memory without limit.
const RENDER_CACHE_MAX_ENTRIES = 300
const RENDER_CACHE_MAX_SOURCE_LENGTH = 10_000
const renderCache = new Map<string, string>()

/** Renders trusted Markdown to HTML. Raw HTML stays escaped (html: false). */
export function renderMarkdown(source?: string | null): string {
  if (!source) return ''
  if (source.length > RENDER_CACHE_MAX_SOURCE_LENGTH) return md.render(source)

  const cached = renderCache.get(source)

  if (cached !== undefined) {
    // Refresh insertion order so frequently used posts survive eviction.
    renderCache.delete(source)
    renderCache.set(source, cached)
    return cached
  }

  const html = md.render(source)

  if (renderCache.size >= RENDER_CACHE_MAX_ENTRIES) {
    const oldest = renderCache.keys().next().value

    if (oldest !== undefined) renderCache.delete(oldest)
  }

  renderCache.set(source, html)
  return html
}

/** Strips Markdown markers so an entry can be previewed as plain text. */
export function markdownToText(source?: string | null): string {
  if (!source) return ''

  return source
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/`([^`]*)`/g, '$1')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/^[ \t]*:::[^\n]*$/gm, ' ')
    .replace(/^\s{0,3}#{1,6}\s+/gm, '')
    .replace(/^\s{0,3}>\s?/gm, '')
    .replace(/^\s*(?:[-*+]|\d+\.)\s+/gm, '')
    .replace(/[*_~]{1,3}([^*_~]+)[*_~]{1,3}/g, '$1')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

export function devlogPreview(source?: string | null, max = DEVLOG_INLINE_MAX_CHARS): string {
  const text = markdownToText(source)
  if (text.length <= max) return text

  const slice = text.slice(0, max)
  const lastSpace = slice.lastIndexOf(' ')

  return `${(lastSpace > max * 0.6 ? slice.slice(0, lastSpace) : slice).trimEnd()}…`
}

export function isLongDevlog(source?: string | null, max = DEVLOG_INLINE_MAX_CHARS): boolean {
  return markdownToText(source).length > max
}
