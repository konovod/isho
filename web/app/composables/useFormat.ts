// Creating an Intl formatter is expensive, and forum pages format dozens of
// dates per render. Keep one formatter per shape for the lifetime of the
// process (SSR) or browser tab.
const DATE_FORMATTER = new Intl.DateTimeFormat('ru-RU', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
})

const DATE_TIME_FORMATTER = new Intl.DateTimeFormat('ru-RU', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
})

const TIME_ZONE_FORMATTERS = new Map<string, Intl.DateTimeFormat>()

function timeZoneFormatter(timeZone: string): Intl.DateTimeFormat {
  let formatter = TIME_ZONE_FORMATTERS.get(timeZone)

  if (!formatter) {
    formatter = new Intl.DateTimeFormat('ru-RU', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      timeZone,
    })
    TIME_ZONE_FORMATTERS.set(timeZone, formatter)
  }

  return formatter
}

export function useFormat() {
  function date(value: string | null | undefined): string {
    if (!value) return '—'
    return DATE_FORMATTER.format(new Date(value))
  }

  function dateTime(value: string | null | undefined): string {
    if (!value) return '—'
    return DATE_TIME_FORMATTER.format(new Date(value))
  }

  // Jam deadlines are shown in the jam's own time zone, not the reader's:
  // "до 23:59 по Москве" must mean the same instant for everyone.
  function dateTimeIn(value: string | null | undefined, timeZone: string): string {
    if (!value) return '—'

    try {
      return timeZoneFormatter(timeZone).format(new Date(value))
    }
    catch {
      return DATE_TIME_FORMATTER.format(new Date(value))
    }
  }

  function bytes(value: number | null | undefined): string {
    if (!value) return ''
    if (value < 1024) return `${value} Б`
    if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} КБ`
    if (value < 1024 * 1024 * 1024) return `${(value / (1024 * 1024)).toFixed(1)} МБ`
    return `${(value / (1024 * 1024 * 1024)).toFixed(1)} ГБ`
  }

  // Russian plural forms: 1 проект, 2 проекта, 5 проектов.
  function plural(value: number, one: string, few: string, many: string): string {
    const mod10 = value % 10
    const mod100 = value % 100

    if (mod10 === 1 && mod100 !== 11) return one
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few
    return many
  }

  return { date, dateTime, dateTimeIn, bytes, plural }
}
