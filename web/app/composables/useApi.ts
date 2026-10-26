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
  reason: 'Причина',
  days: 'Срок',
  ai_usage: 'Использование ИИ',
  max_ai_usage: 'Уровень ИИ',
  show_nsfw: 'Показ проектов 18+',
  nsfw: '18+',
  total_bytes: 'Размер файла',
  filename: 'Имя файла',
  kind: 'Тип сборки',
  entry: 'Стартовый файл',
  slug: 'Адрес раздела',
  group_title: 'Группа',
  position: 'Позиция',
  parent_id: 'Родительский раздел',
  cancel_reason: 'Причина отмены',
  starts_at: 'Дата старта',
  submissions_close_at: 'Конец приёма заявок',
  voting_closes_at: 'Конец судейства',
  time_zone: 'Часовой пояс',
  judging_mode: 'Кто оценивает',
  score_scale: 'Шкала оценок',
  criteria: 'Критерии',
  theme: 'Тема',
  rules: 'Правила',
  prizes: 'Призы',
  results_note: 'Итоги',
  project_slug: 'Проект',
  disqualified_reason: 'Причина снятия',
  jam_scores: 'Оценки',
  criterion_id: 'Критерий',
  score: 'Балл',
  comment: 'Отзыв',
}

const detailMessages: Record<string, string> = {
  'is required': 'обязательное поле',
  'is too long': 'слишком длинное',
  'is too short': 'слишком короткое',
  'must have at least 6 characters': 'минимум 6 символов',
  'must not have more than 72 characters': 'максимум 72 символа',
  'is invalid': 'неверное значение',
  'has already been taken': 'уже занято',
  'is not allowed': 'нельзя использовать для регистрации',
  'must be at least 1': 'минимум 1',
  'must be at most 3650': 'максимум 3650',
  'must be a public https:// link': 'нужна публичная ссылка https://',
  'must not point to a local address': 'нельзя ссылаться на локальный адрес',
  'must be a post in this topic': 'можно цитировать только сообщение из этой темы',
  'must be ai_free, partial, significant or full': 'нужно выбрать один из уровней',
  'can not be changed for a section with topics': 'нельзя менять у раздела с темами',
  'can not be changed for a section with topics or subsections': 'нельзя менять у раздела с темами или подразделами',
  'does not exist': 'такого раздела нет',
  'can not point to itself': 'раздел не может быть родителем сам себе',
  'must be a root section': 'родителем может быть только корневой раздел',
  'can not be added to a section with subsections': 'раздел с подразделами нельзя сделать подразделом',
  'can not be changed for a protected section': 'этот раздел всегда корневой',
  'must be after the start': 'должно быть позже старта',
  'must be after submissions close': 'должно быть позже конца приёма заявок',
  'is not a known time zone': 'неизвестный часовой пояс',
  'must be community, participants or jury': 'нужно выбрать один из режимов оценки',
  'must be community or participants': 'нужно выбрать, чьи баллы идут в итоги',
  'must be 5 or 10': 'нужно выбрать шкалу 1–5 или 1–10',
  'can not be changed after publication': 'нельзя менять после публикации',
  'can not be changed after scoring starts': 'нельзя менять после начала оценивания',
  'can not have more than 10 criteria': 'нельзя добавить больше 10 критериев',
  'must be between 1 and 3': 'вес должен быть от 1 до 3',
  'at least one criterion is required': 'нужен хотя бы один критерий',
  'must include every criterion': 'нужно оценить каждый критерий',
  'does not belong to this jam': 'критерий относится к другому джему',
  'is duplicated': 'критерий указан дважды',
  'is out of range': 'балл вне выбранной шкалы',
}

const codeMessages: Record<string, string> = {
  email_not_confirmed: 'Подтвердите почту — тогда можно публиковать проекты, писать на форуме и в личных сообщениях.',
  invalid_token: 'Ссылка недействительна или устарела. Запросите новое письмо.',
  email_delivery_failed: 'Не удалось отправить письмо. Попробуйте позже.',
  too_many_requests: 'Слишком много запросов подряд. Подождите немного.',
  unauthorized: 'Нужно войти в аккаунт.',
  user_banned: 'Аккаунт забанен — публикация недоступна до окончания срока.',
  own_post: 'Нельзя голосовать за своё сообщение.',
  cannot_message_self: 'Нельзя переписываться с самим собой.',
  cannot_ban_self: 'Нельзя забанить свой аккаунт.',
  cannot_ban_admin: 'Нельзя забанить администратора.',
  cannot_impersonate_self: 'Нельзя войти от имени своего аккаунта.',
  cannot_impersonate_admin: 'Нельзя войти от имени администратора.',
  impersonation_read_only: 'Режим просмотра: изменения недоступны. Вернитесь в свой аккаунт.',
  build_limit_reached: 'У проекта уже предельное число сборок — удалите одну.',
  project_storage_quota_exceeded: 'Не хватает места в лимите проекта: 300 МБ на сборки.',
  storage_quota_exceeded: 'Не хватает места в лимите аккаунта: 1 ГБ на сборки, скриншоты и картинки.',
  storage_full: 'На сервере закончилось место для загрузок. Попробуйте позже.',
  upload_incomplete: 'Файл загружен не полностью. Повторите загрузку.',
  invalid_chunk: 'Кусок файла пришёл не по порядку. Загрузка начнётся заново.',
  upload_complete: 'Файл уже загружен.',
  upload_interrupted: 'Связь прервалась во время загрузки. Повторите попытку.',
  upload_cancelled: 'Загрузка отменена.',
  invalid_upload: 'Загрузка повреждена. Начните заново.',
  file_too_large: 'Файл слишком большой: до 300 МБ на сборку.',
  invalid_archive: 'Архив повреждён или содержит недопустимые пути.',
  archive_too_many_files: 'В архиве слишком много файлов.',
  archive_too_large: 'Архив распаковывается в больший размер, чем заявлен.',
  empty_archive: 'Архив пустой.',
  index_html_missing: 'В архиве нет index.html — добавьте его или укажите стартовый файл.',
  index_html_ambiguous: 'В архиве несколько index.html — укажите стартовый файл вручную.',
  entry_not_found: 'Указанный стартовый файл не найден в архиве.',
  protected_section: 'Этот раздел удалить нельзя.',
  section_has_children: 'В разделе есть подразделы — сначала удалите или перенесите их.',
  section_not_empty: 'В разделе есть темы — удалить можно только пустой раздел.',
  jam_not_ready: 'Заполните даты и добавьте хотя бы один критерий.',
  jam_already_published: 'Джем уже опубликован.',
  jam_canceled: 'Джем отменён.',
  jam_not_draft: 'Удалить можно только черновик; опубликованный джем отменяют.',
  jam_banner_too_large: 'Файл слишком большой — баннер должен быть до 5 МБ.',
  invalid_file_type: 'Поддерживаются PNG, JPEG и WebP.',
  jam_not_open: 'Приём заявок закрыт.',
  project_not_found: 'Проект не найден среди ваших проектов.',
  project_not_published: 'Сначала опубликуйте проект.',
  already_submitted: 'Этот проект уже подан в этот джем.',
  entry_locked: 'Приём заявок закрыт — отозвать заявку может только организатор.',
  already_disqualified: 'Заявка уже снята.',
  entry_not_disqualified: 'Заявка не снята.',
  judging_closed: 'Судейство ещё не началось или уже закончилось.',
  own_entry: 'Свою заявку оценивать нельзя.',
  entry_disqualified: 'Снятую заявку оценивать нельзя.',
  criteria_locked: 'Критерии нельзя менять после начала оценивания.',
  criteria_missing: 'У джема нет критериев для оценки.',
  feedback_not_ready: 'Отзывы откроются после окончания судейства.',
}

function translateDetail(message: string): string {
  const size = message.match(/^must not have more than (\d+) characters$/)
  if (size) return `не длиннее ${size[1]} символов`

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
