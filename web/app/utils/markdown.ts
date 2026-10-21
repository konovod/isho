import MarkdownIt from 'markdown-it'

/** Devlogs longer than this are previewed on the project page with a link. */
export const DEVLOG_INLINE_MAX_CHARS = 600

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

/** Renders trusted Markdown to HTML. Raw HTML stays escaped (html: false). */
export function renderMarkdown(source?: string | null): string {
  return source ? md.render(source) : ''
}

/** Strips Markdown markers so an entry can be previewed as plain text. */
export function markdownToText(source?: string | null): string {
  if (!source) return ''

  return source
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/`([^`]*)`/g, '$1')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
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
