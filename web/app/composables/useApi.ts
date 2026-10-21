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

const fieldNames: Record<string, string> = {
  label: 'Название',
  url: 'Ссылка',
  title: 'Название',
  body: 'Текст',
  quoted_post_id: 'Цитата',
  tagline: 'Короткое описание',
  description: 'Описание',
  image_file: 'Файл',
  caption: 'Подпись',
  username: 'Имя пользователя',
  email: 'Почта',
  password: 'Пароль',
  password_confirmation: 'Повтор пароля',
  moderation_note: 'Причина',
}

const detailMessages: Record<string, string> = {
  'is required': 'обязательное поле',
  'is too long': 'слишком длинное',
  'is too short': 'слишком короткое',
  'is invalid': 'неверное значение',
  'has already been taken': 'уже занято',
  'must be a public https:// link': 'нужна публичная ссылка https://',
  'must not point to a local address': 'нельзя ссылаться на локальный адрес',
  'must be a post in this topic': 'можно цитировать только сообщение из этой темы',
}

const codeMessages: Record<string, string> = {
  email_not_confirmed: 'Подтвердите почту — тогда можно публиковать проекты и писать на форуме.',
  invalid_token: 'Ссылка недействительна или устарела. Запросите новое письмо.',
  email_delivery_failed: 'Не удалось отправить письмо. Попробуйте позже.',
  too_many_requests: 'Слишком много попыток. Попробуйте позже.',
  unauthorized: 'Нужно войти в аккаунт.',
}

function translateDetail(message: string): string {
  return detailMessages[message] ?? message
}

export function formatApiError(err: unknown, fallback = 'Что-то пошло не так'): string {
  if (!(err instanceof ApiError)) return fallback

  if (err.code === 'validation_failed' && err.details) {
    const details = Object.entries(err.details)
      .map(([field, messages]) => `${fieldNames[field] ?? field}: ${messages.map(translateDetail).join(', ')}`)
      .join('; ')

    if (details) return `Проверьте поля — ${details}`
  }

  return codeMessages[err.code] ?? err.message
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
