/** Sizes are stored in bytes and shown in the decimal units the limits use. */
export function formatBytes(bytes: number | null | undefined): string {
  if (!bytes || bytes <= 0) return '0 МБ'

  const mb = bytes / 1_000_000
  if (mb < 1) return `${Math.max(1, Math.round(bytes / 1000))} КБ`
  if (mb < 10) return `${Number(mb.toFixed(1))} МБ`
  if (mb < 1000) return `${Math.round(mb)} МБ`

  return `${Number((mb / 1000).toFixed(2))} ГБ`
}

/** Width of a quota bar in percent, already clamped to 100. */
export function quotaPercent(used?: number | null, limit?: number | null): string {
  if (!used || !limit || limit <= 0) return '0%'
  return `${Math.min(100, Math.round((used / limit) * 100))}%`
}
