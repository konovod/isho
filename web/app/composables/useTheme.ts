import type { Theme } from '~/types/api'

export const THEME_COOKIE = 'isho_theme'

function normalizeTheme(value: unknown): Theme | null {
  return value === 'light' || value === 'dark' ? value : null
}

function systemTheme(): Theme {
  return window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'
}

export function useTheme() {
  // The cookie is readable during SSR, so the server can paint the chosen
  // theme into the first response instead of flashing after hydration.
  const cookie = useCookie<Theme | null>(THEME_COOKIE, {
    path: '/',
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 365,
    default: () => null,
  })

  // `null` means the visitor has not chosen yet: guests then follow their OS
  // theme through CSS, and the account setting wins once they sign in.
  const theme = useState<Theme | null>('theme', () => normalizeTheme(cookie.value))

  function setTheme(next: Theme) {
    theme.value = next
    cookie.value = next
  }

  function applyUserTheme(value: string | null | undefined) {
    const next = normalizeTheme(value)
    if (!next || theme.value === next) return

    theme.value = next
    cookie.value = next
  }

  /** Flips the theme and returns the new value. */
  function toggleTheme(): Theme {
    const current = theme.value ?? (import.meta.client ? systemTheme() : 'dark')
    const next: Theme = current === 'dark' ? 'light' : 'dark'
    setTheme(next)
    return next
  }

  return { theme, setTheme, toggleTheme, applyUserTheme }
}
