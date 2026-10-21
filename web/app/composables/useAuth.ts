import type { Me } from '~/types/api'

export function useAuth() {
  const user = useState<Me | null>('auth.user', () => null)
  const loaded = useState<boolean>('auth.loaded', () => false)
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

  async function signIn(email: string, password: string): Promise<Me> {
    user.value = await api.post<Me>('/api/v1/sign_ins', { user: { email, password } })
    loaded.value = true
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
  }

  return { user, loaded, fetchMe, signIn, signUp, signOut }
}
