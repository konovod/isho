import type { Build } from '~/types/api'

/** The author's counter for a build, or null when the API hid it. */
export function buildUsageLabel(build: Build): string | null {
  const count = build.kind === 'web' ? build.launches_count : build.downloads_count
  if (count === undefined) return null

  return build.kind === 'web' ? `Запусков: ${count}` : `Скачиваний: ${count}`
}
