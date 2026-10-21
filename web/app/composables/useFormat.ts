export function useFormat() {
  function date(value: string | null | undefined): string {
    if (!value) return '—'
    return new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(value))
  }

  function dateTime(value: string | null | undefined): string {
    if (!value) return '—'
    return new Intl.DateTimeFormat('ru-RU', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date(value))
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

  return { date, dateTime, bytes, plural }
}
