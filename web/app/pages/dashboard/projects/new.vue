<script setup lang="ts">
import type { AiUsage, ImportJob, ProjectDetail, ProjectDevStatus, ProjectGenre, ProjectKind, Tag, TagDraft } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const api = useApi()
const router = useRouter()

const { data: tagData } = await useAsyncData(
  'new-project-tags',
  () => api.get<{ items: Tag[] }>('/api/v1/tags?min_projects=1'),
)

const allTags = computed(() => tagData.value?.items ?? [])
const selectedTags = ref<TagDraft[]>([])

const form = reactive({
  title: '',
  tagline: '',
  description: '',
  kind: 'game' as ProjectKind,
  dev_status: 'active' as ProjectDevStatus,
  genre: '' as ProjectGenre | '',
  nsfw: false,
  ai_usage: 'ai_free' as AiUsage,
})

// Tools and assets have no genre; keeping a stale value would make the edit
// form send a field the server has to drop anyway.
watch(() => form.kind, (value) => {
  if (value !== 'game') form.genre = ''
})

const error = ref('')
const pending = ref(false)

/* Import from a page */

const importUrl = ref('')
const importing = ref(false)
const importStep = ref('fetch')
const importError = ref('')
let importTimer: ReturnType<typeof setInterval> | null = null

const importSteps: Record<string, string> = {
  fetch: 'Скачиваем страницу',
  extract: 'Разбираем содержимое',
  ai: 'Просим ИИ описать игру',
  screenshots: 'Загружаем скриншоты',
  done: 'Готово',
}

async function startImport() {
  importError.value = ''
  const source = importUrl.value.trim()
  if (!source) return

  importing.value = true
  importStep.value = 'fetch'

  try {
    const result = await api.post<{ import: ImportJob }>('/api/v1/projects/imports', {
      import: { source_url: source },
    })
    pollImport(result.import.id)
  }
  catch (err) {
    importError.value = formatApiError(err, 'Не удалось начать импорт')
    importing.value = false
  }
}

// The draft appears while the screenshots may still be arriving, so the page
// leaves as soon as the slug exists and the edit page finishes the waiting.
function pollImport(id: number) {
  stopImportPolling()
  importTimer = setInterval(async () => {
    try {
      const result = await api.get<{ import: ImportJob }>(`/api/v1/projects/imports/${id}`)
      importStep.value = result.import.step

      if (result.import.project_slug) {
        stopImportPolling()
        await router.push(`/dashboard/projects/${result.import.project_slug}/edit?imported=1&import=${result.import.id}`)
        return
      }

      if (['failed', 'skipped', 'cancelled'].includes(result.import.status)) {
        stopImportPolling()
        importing.value = false
        importError.value = result.import.error || 'Не удалось собрать черновик по ссылке'
      }
    }
    catch {
      // A lost poll is not fatal: the next tick asks again.
    }
  }, 2000)
}

function stopImportPolling() {
  if (importTimer) clearInterval(importTimer)
  importTimer = null
}

onBeforeUnmount(stopImportPolling)

async function submit() {
  error.value = ''
  pending.value = true

  try {
    const project = await api.post<ProjectDetail>('/api/v1/projects', {
      project: {
        title: form.title.trim(),
        tagline: form.tagline.trim() || undefined,
        description: form.description.trim() || undefined,
        kind: form.kind,
        dev_status: form.dev_status,
        genre: form.genre,
        nsfw: form.nsfw,
        ai_usage: form.ai_usage,
      },
      tag_names: selectedTags.value.map(tag => tag.name),
    })

    await refreshNuxtData()
    await router.push(`/dashboard/projects/${project.slug}/edit`)
  }
  catch (err) {
    error.value = formatApiError(err, 'Не удалось создать проект')
  }
  finally {
    pending.value = false
  }
}
</script>

<template>
  <div class="container">
    <div class="page-head">
      <div>
        <h1>Новый проект</h1>
        <p>Название и обложку можно изменить позже.</p>
      </div>
    </div>

    <div class="card card-pad" style="max-width: 640px; margin-bottom: 16px;">
      <div class="field" style="margin-top: 0;">
        <label class="label" for="import-url">Заполнить из ссылки</label>
        <div class="row">
          <input
            id="import-url"
            v-model="importUrl"
            class="input"
            type="url"
            placeholder="https://store.steampowered.com/app/… или страница на itch.io"
            :disabled="importing"
            style="flex: 1; min-width: 220px;"
          >
          <button
            class="btn btn-primary"
            type="button"
            :disabled="importing || !importUrl.trim()"
            @click="startImport"
          >
            {{ importing ? 'Собираем…' : 'Импортировать' }}
          </button>
        </div>
        <span class="hint">
          Страница разбирается один раз: название, описание, жанр, теги и скриншоты.
          Черновик появится через несколько секунд — его нужно проверить.
        </span>
      </div>

      <p v-if="importing" class="hint">
        {{ importSteps[importStep] || 'Работаем…' }}
      </p>
      <div v-if="importError" class="form-error">
        {{ importError }}
      </div>
    </div>

    <div class="card card-pad" style="max-width: 640px;">
      <div v-if="error" class="form-error">
        {{ error }}
      </div>

      <form @submit.prevent="submit">
        <div class="field">
          <label class="label" for="title">Название</label>
          <input id="title" v-model="form.title" class="input" maxlength="120" required>
        </div>

        <div class="field">
          <label class="label" for="tagline">Короткое описание</label>
          <input id="tagline" v-model="form.tagline" class="input" maxlength="160" placeholder="Одна строка о проекте">
        </div>

        <div class="field">
          <label class="label" for="kind">Тип</label>
          <select id="kind" v-model="form.kind" class="select">
            <option v-for="option in PROJECT_KINDS" :key="option.value" :value="option.value">
              {{ option.label }}
            </option>
          </select>
        </div>

        <div class="field">
          <label class="label" for="dev-status">Статус</label>
          <select id="dev-status" v-model="form.dev_status" class="select">
            <option v-for="option in PROJECT_DEV_STATUSES" :key="option.value" :value="option.value">
              {{ option.label }}
            </option>
          </select>
        </div>

        <div class="field">
          <label class="label" for="genre">Жанр</label>
          <select
            id="genre"
            v-model="form.genre"
            class="select"
            :disabled="form.kind !== 'game'"
          >
            <option value="">
              Без жанра
            </option>
            <option v-for="option in PROJECT_GENRES" :key="option.value" :value="option.value">
              {{ option.label }}
            </option>
          </select>
          <span class="hint">
            {{ form.kind === 'game' ? 'Жанр помогает найти игру в каталоге.' : 'Жанр есть только у игр.' }}
          </span>
        </div>

        <div class="field">
          <label class="label" for="ai-usage">Использование ИИ</label>
          <select id="ai-usage" v-model="form.ai_usage" class="select">
            <option v-for="option in AI_USAGE_OPTIONS" :key="option.value" :value="option.value">
              {{ option.label }}
            </option>
          </select>
          <span class="hint">{{ aiUsageOption(form.ai_usage).description }}</span>
        </div>

        <div class="field">
          <label class="check-row">
            <input v-model="form.nsfw" type="checkbox" aria-label="Проект для взрослых (18+)">
            <span>
              <span class="check-title">Проект для взрослых (18+)</span>
              <span class="hint">
                Не показывается гостям. Зарегистрированные пользователи могут скрыть такие
                проекты в настройках.
              </span>
            </span>
          </label>
        </div>

        <div class="field">
          <label class="label" for="description">Описание</label>
          <MarkdownEditor
            id="description"
            v-model="form.description"
            :maxlength="20000"
            :rows="12"
            placeholder="Что это, для кого и как играть. Поддерживается Markdown."
          />
        </div>

        <div class="field">
          <label class="label">Теги</label>
          <TagInput v-model="selectedTags" :suggestions="allTags" :max="8" />
        </div>

        <div class="row">
          <button class="btn btn-primary" type="submit" :disabled="pending">
            {{ pending ? 'Создаём…' : 'Создать черновик' }}
          </button>
          <NuxtLink to="/dashboard" class="btn btn-ghost">
            Отмена
          </NuxtLink>
        </div>
      </form>
    </div>
  </div>
</template>
