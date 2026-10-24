// `<input type="datetime-local">` has no time zone. A jam stores deadlines as
// instants plus a display time zone, so the form value must be interpreted in
// the jam's zone rather than in the browser's.

function pad(value: number): string {
  return String(value).padStart(2, '0')
}

function partsInZone(date: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date)

  const value = (type: string): number => Number(parts.find(part => part.type === type)?.value)

  return {
    year: value('year'),
    month: value('month'),
    day: value('day'),
    hour: value('hour'),
    minute: value('minute'),
    second: value('second'),
  }
}

/** "2026-11-01T09:00" in `timeZone` → ISO instant. */
export function zonedDateTimeToIso(value: string, timeZone: string): string | undefined {
  if (!value) return undefined

  const [datePart, timePart] = value.split('T')
  if (!datePart || !timePart) return undefined

  const [year, month, day] = datePart.split('-').map(Number)
  const [hour, minute] = timePart.split(':').map(Number)

  if ([year, month, day, hour, minute].some(Number.isNaN)) return undefined

  const guess = Date.UTC(year!, month! - 1, day!, hour!, minute!)
  const inZone = partsInZone(new Date(guess), timeZone)
  const asZoneUtc = Date.UTC(
    inZone.year,
    inZone.month - 1,
    inZone.day,
    inZone.hour,
    inZone.minute,
    inZone.second,
  )

  return new Date(guess - (asZoneUtc - guess)).toISOString()
}

/** ISO instant → "2026-11-01T09:00" in `timeZone`. */
export function isoToZonedDateTime(value: string | null | undefined, timeZone: string): string {
  if (!value) return ''

  const parts = partsInZone(new Date(value), timeZone)
  return `${parts.year}-${pad(parts.month)}-${pad(parts.day)}T${pad(parts.hour)}:${pad(parts.minute)}`
}
