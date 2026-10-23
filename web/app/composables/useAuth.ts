import type { Me, Theme } from '~/types/api'

export interface ResendConfirmationResult {
  sent: boolean
  retry_after?: number
  already_confirmed?: boolean
}

/** The reset request answers the same way for every address. */
export interface PasswordResetRequestResult {
  sent: boolean
}

export function useAuth() {
  const user = useState<Me | null>('auth.user', () => null)
  const loaded = useState<boolean>('auth.loaded', () => false)
  const canModerate = computed(() => user.value?.is_admin === true)
  // Visitors and accounts created before confirmation existed are not nagged.
  const emailConfirmed = computed(() => user.value?.email_confirmed !== false)
  const banned = computed(() => !!user.value?.ban)
  const api = useApi()

  async function fetchMe(force = false): Promise<Me | null> {
    if (loaded.value && !force) return user.value

    try {
      user.value = await api.get<Me>('/api/v1/me')
    }
    catch {
      user.value = null
    }
    finally {
      loaded.value = true
    }

    return user.value
  }

  async function signIn(login: string, password: string): Promise<Me> {
    user.value = await api.post<Me>('/api/v1/sign_ins', { user: { login, password } })
    loaded.value = true
    // Catalogues are filtered per viewer, so cached pages from the visitor
    // session must not be reused by the account.
    clearNuxtData()
    return user.value
  }

  async function signUp(payload: {
    email: string
    username: string
    display_name?: string
    password: string
    password_confirmation: string
  }): Promise<Me> {
    user.value = await api.post<Me>('/api/v1/sign_ups', { user: payload })
    loaded.value = true
    clearNuxtData()
    return user.value
  }

  async function resendEmailConfirmation(): Promise<ResendConfirmationResult> {
    return await api.post<ResendConfirmationResult>('/api/v1/email_confirmations/resend')
  }

  async function requestPasswordReset(email: string): Promise<PasswordResetRequestResult> {
    return await api.post<PasswordResetRequestResult>('/api/v1/password_resets', { user: { email } })
  }

  // The API closes every session opened with the old password and starts a new
  // one, so the browser is signed in as soon as the call succeeds.
  async function resetPassword(token: string, password: string, passwordConfirmation: string): Promise<Me> {
    user.value = await api.post<Me>(
      `/api/v1/password_resets/${encodeURIComponent(token)}`,
      { user: { password, password_confirmation: passwordConfirmation } },
    )
    loaded.value = true
    clearNuxtData()
    return user.value
  }

  async function signOut(): Promise<void> {
    try {
      await api.del('/api/v1/sign_ins')
    }
    catch {
      // Clearing local state is still correct if the session already expired.
    }
    user.value = null
    loaded.value = true
    // Do not leave pages filtered for the account in the client cache.
    clearNuxtData()
  }

  async function saveTheme(next: Theme): Promise<void> {
    try {
      user.value = await api.patch<Me>('/api/v1/me/theme', { user: { theme: next } })
    }
    catch {
      // The cookie still keeps the choice on this device if the API call fails.
    }
  }

  return { user, loaded, canModerate, emailConfirmed, banned, fetchMe, signIn, signUp, resendEmailConfirmation, requestPasswordReset, resetPassword, signOut, saveTheme }
}
