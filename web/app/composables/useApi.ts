import type { ApiErrorPayload } from '~/types/api'

export class ApiError extends Error {
  code: string
  details: Record<string, string[]> | null

  constructor(code: string, message: string, details: Record<string, string[]> | null = null) {
    super(message)
    this.name = 'ApiError'
    this.code = code
    this.details = details
  }

  fieldError(field: string): string | null {
    return this.details?.[field]?.[0] ?? null
  }
}

export function useApi() {
  const config = useRuntimeConfig()

  // The browser talks to the same origin (Nuxt proxies /api and /media in dev;
  // Caddy routes them to Lucky in production). During SSR we talk to the API
  // directly and forward the visitor's cookie.
  const base = import.meta.server
    ? (config.apiInternalBase as string)
    : (config.public.apiBase as string)

  const cookie = import.meta.server ? useRequestHeaders(['cookie']).cookie : undefined

  async function call<T>(path: string, options: Record<string, any> = {}): Promise<T> {
    try {
      return await $fetch<T>(`${base}${path}`, {
        headers: {
          Accept: 'application/json',
          ...(cookie ? { cookie } : {}),
          ...(options.headers ?? {}),
        },
        ...options,
      })
    }
    catch (error: any) {
      const payload = (error?.data ?? error?.response?._data) as ApiErrorPayload | undefined
      const apiError = payload?.error

      throw new ApiError(
        apiError?.code ?? 'network_error',
        apiError?.message ?? 'Не удалось связаться с сервером',
        apiError?.details ?? null,
      )
    }
  }

  return {
    get: <T>(path: string, query?: Record<string, any>) => call<T>(path, { query }),
    post: <T>(path: string, body?: any) => call<T>(path, { method: 'POST', body }),
    patch: <T>(path: string, body?: any) => call<T>(path, { method: 'PATCH', body }),
    put: <T>(path: string, body?: any) => call<T>(path, { method: 'PUT', body }),
    del: <T>(path: string) => call<T>(path, { method: 'DELETE' }),
    upload: <T>(path: string, body: FormData) => call<T>(path, { method: 'POST', body }),
  }
}
