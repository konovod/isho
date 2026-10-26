<script setup lang="ts">
import type { ForumSection, ForumTopic, TopicSuggestion } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const DRAFT_KEY = 'isho:forum-topic-draft'
const DRAFT_TTL_MS = 15 * 60 * 1000

interface TopicDraft {
  section: string
  title: string
  body: string
  at: number
}

const route = useRoute()
const api = useApi()
const { user } = useAuth()

const sectionSlug = computed(() => route.params.section as string)
const form = reactive({ title: '', body: '', request_ai_answer: true })
const saving = ref(false)
const busy = ref(false)
const error = ref('')
const notice = ref('')

const suggestion = ref<TopicSuggestion | null>(null)
// The suggestion is asked for once per submit, and "create here" must not
// trigger it again.
const suggestionChecked = ref(false)

const { data: section } = await useAsyncData(
  `forum-new-topic-section-${sectionSlug.value}`,
  () => api.get<{ section: ForumSection }>(`/api/v1/forum/sections/${sectionSlug.value}`),
)

if (!section.value) {
  throw createError({ statusCode: 404, statusMessage: 'Раздел не найден' })
}

useSeoMeta({
  title: () => `Новая тема — ${section.value?.section.title || 'Форум'} — ${SITE_NAME}`,
})

const aiEnabled = computed(() => !!user.value?.ai?.enabled && !!section.value?.section.ai_answers_enabled)
const answersLeft = computed(() => user.value?.ai?.answers_left ?? 0)
const aiAvailable = computed(() => aiEnabled.value && answersLeft.value > 0)

const suggestionTarget = computed(() => suggestion.value?.section ?? null)

function saveDraft() {
  if (!import.meta.client) return

  const draft: TopicDraft = {
    section: sectionSlug.value,
    title: form.title,
    body: form.body,
    at: Date.now(),
  }

  sessionStorage.setItem(DRAFT_KEY, JSON.stringify(draft))
}

function restoreDraft() {
  if (!import.meta.client) return

  const raw = sessionStorage.getItem(DRAFT_KEY)
  if (!raw) return

  sessionStorage.removeItem(DRAFT_KEY)

  try {
    const draft = JSON.parse(raw) as TopicDraft
    if (Date.now() - draft.at > DRAFT_TTL_MS) return
    if (draft.section === sectionSlug.value) return

    form.title = draft.title
    form.body = draft.body
    notice.value = 'Черновик перенесён из другого раздела.'
  }
  catch {
    // A broken draft is not worth an error on a blank form.
  }
}

onMounted(restoreDraft)

function validate(): boolean {
  if (!form.title.trim()) {
    error.value = 'Укажите название темы.'
    return false
  }

  if (!form.body.trim()) {
    error.value = 'Добавьте текст первого сообщения.'
    return false
  }

  return true
}

async function submit() {
  if (busy.value) return
  error.value = ''

  if (!validate()) return

  busy.value = true
  saving.value = true

  try {
    if (!suggestionChecked.value) {
      suggestionChecked.value = true

      const result = await askForSuggestion()
      if (result) {
        suggestion.value = result
        return
      }
    }

    await createTopic()
  }
  finally {
    busy.value = false
    saving.value = false
  }
}

async function askForSuggestion(): Promise<TopicSuggestion | null> {
  try {
    const result = await api.post<{ suggestion: TopicSuggestion | null }>('/api/v1/forum/topic_suggestions', {
      forum_topic: {
        section_slug: sectionSlug.value,
        title: form.title.trim(),
        body: form.body.trim(),
      },
    })

    if (!result.suggestion) return null
    if (result.suggestion.section.slug === sectionSlug.value) return null

    return result.suggestion
  }
  catch {
    // The hint is optional: rate limits, provider outages and a missing key
    // must never stop a topic from being created.
    return null
  }
}

async function createTopic() {
  error.value = ''

  try {
    const topic = await api.post<ForumTopic>(`/api/v1/forum/sections/${sectionSlug.value}/topics`, {
      forum_topic: {
        title: form.title.trim(),
        body: form.body.trim(),
        request_ai_answer: aiAvailable.value && form.request_ai_answer ? 'true' : 'false',
      },
    })

    await navigateTo(`/forum/${topic.section.slug}/${topic.slug}`)
  }
  catch (err) {
    error.value = formatApiError(err)
  }
}

async function createAnyway() {
  if (busy.value) return

  suggestion.value = null
  suggestionChecked.value = true
  busy.value = true
  saving.value = true

  try {
    await createTopic()
  }
  finally {
    busy.value = false
    saving.value = false
  }
}

async function moveToSuggested() {
  const target = suggestionTarget.value
  if (!target) return

  saveDraft()
  await navigateTo(`/forum/${target.slug}/new`)
}
</script>

<template>
  <div class="container forum-page">
    <nav class="forum-crumbs" aria-label="Хлебные крошки">
      <NuxtLink to="/forum">Форум</NuxtLink>
      <span class="forum-crumb-sep" aria-hidden="true">›</span>
      <NuxtLink :to="`/forum/${sectionSlug}`">
        {{ section?.section.title || 'Раздел' }}
      </NuxtLink>
      <span class="forum-crumb-sep" aria-hidden="true">›</span>
      <span>Новая тема</span>
    </nav>

    <div class="page-head">
      <div>
        <h1>Новая тема</h1>
        <p>Заголовок и первое сообщение. Markdown поддерживается.</p>
      </div>
    </div>

    <div class="card card-pad forum-topic-form">
      <div v-if="error" class="form-error">
        {{ error }}
      </div>
      <div v-if="notice" class="form-success">
        {{ notice }}
      </div>

      <div v-if="suggestion" class="topic-suggestion">
        <p class="topic-suggestion-text">
          Похоже, тема больше про <strong>«{{ suggestion.section.title }}»</strong>.
          <template v-if="suggestion.reason">
            {{ suggestion.reason }}
          </template>
        </p>
        <div class="row">
          <button type="button" class="btn btn-primary btn-sm" :disabled="saving" @click="moveToSuggested">
            Перейти в «{{ suggestion.section.title }}»
          </button>
          <button type="button" class="btn btn-ghost btn-sm" :disabled="saving" @click="createAnyway">
            Создать здесь
          </button>
        </div>
      </div>

      <div class="field">
        <label class="label" for="forum-topic-title">Название</label>
        <input
          id="forum-topic-title"
          v-model="form.title"
          class="input"
          maxlength="160"
          placeholder="О чём поговорим?"
        >
      </div>

      <div class="field">
        <label class="label" for="forum-topic-body">Первое сообщение</label>
        <MarkdownEditor
          id="forum-topic-body"
          v-model="form.body"
          :rows="14"
          :maxlength="20000"
          placeholder="Расскажите подробнее…"
        />
      </div>

      <label v-if="aiAvailable" class="check-row ai-answer-check">
        <input v-model="form.request_ai_answer" type="checkbox">
        <span>
          <span class="check-title">Ответ от ИИ</span>
          <span class="hint">
            Модель ответит на тему первым сообщением под спойлером.
            Осталось {{ answersLeft }} из {{ user?.ai?.answers_per_day ?? 3 }} сегодня.
          </span>
        </span>
      </label>

      <p v-else-if="aiEnabled" class="muted small ai-answer-check">
        Ответ ИИ на сегодня закончился — вернётся после полуночи UTC.
      </p>

      <div class="row">
        <button class="btn btn-primary" :disabled="saving" @click="submit">
          {{ saving ? 'Создаём…' : 'Создать тему' }}
        </button>
        <NuxtLink :to="`/forum/${sectionSlug}`" class="btn btn-ghost">
          Отмена
        </NuxtLink>
      </div>
    </div>
  </div>
</template>
