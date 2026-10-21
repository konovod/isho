<script setup lang="ts">
import type { Download, ProjectDetail, Screenshot, Tag } from '~/types/api'
import { ApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const route = useRoute()
const router = useRouter()
const api = useApi()
const slug = route.params.slug as string

const { data, pending, error: loadError, refresh } = await useAsyncData(
  `edit-${slug}`,
  async () => {
    const [project, tags] = await Promise.all([
      api.get<ProjectDetail>(`/api/v1/projects/${slug}`),
      api.get<{ items: Tag[] }>('/api/v1/tags'),
    ])

    return { project, tags: tags.items }
  },
)

const project = computed(() => data.value?.project ?? null)
const allTags = computed(() => data.value?.tags ?? [])

const tab = ref<'details' | 'screenshots' | 'downloads'>('details')
const form = reactive({ title: '', tagline: '', description: '', kind: 'game' })
const selectedTags = ref<string[]>([])
const error = ref('')
const notice = ref('')
const saving = ref(false)

watch(project, (value) => {
  if (!value) return
  form.title = value.title
  form.tagline = value.tagline ?? ''
  form.description = value.description ?? ''
  form.kind = value.kind
  selectedTags.value = value.tags.map(tag => tag.slug)
}, { immediate: true })

function fail(err: unknown) {
  error.value = err instanceof ApiError ? err.message : 'Что-то пошло не так'
}

function clearMessages() {
  error.value = ''
  notice.value = ''
}

async function save() {
  clearMessages()
  saving.value = true

  try {
    const updated = await api.patch<ProjectDetail>(`/api/v1/projects/${slug}`, {
      project: {
        title: form.title.trim(),
        tagline: form.tagline.trim() || undefined,
        description: form.description.trim() || undefined,
        kind: form.kind,
      },
      tag_slugs: selectedTags.value,
    })

    data.value!.project = updated
    notice.value = 'Сохранено'
  }
  catch (err) {
    fail(err)
  }
  finally {
    saving.value = false
  }
}

async function togglePublish() {
  if (!project.value) return
  clearMessages()

  try {
    const action = project.value.status === 'published' ? 'unpublish' : 'publish'
    data.value!.project = await api.post<ProjectDetail>(`/api/v1/projects/${slug}/${action}`)
    notice.value = action === 'publish' ? 'Проект опубликован' : 'Проект снят с публикации'
  }
  catch (err) {
    fail(err)
  }
}

async function removeProject() {
  if (!confirm('Удалить проект вместе со скриншотами?')) return
  clearMessages()

  try {
    await api.del(`/api/v1/projects/${slug}`)
    await router.push('/dashboard')
  }
  catch (err) {
    fail(err)
  }
}

/* Screenshots */

const fileInput = ref<HTMLInputElement | null>(null)
const caption = ref('')
const uploading = ref(false)

async function uploadScreenshot(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file || !project.value) return

  clearMessages()
  uploading.value = true

  try {
    const body = new FormData()
    body.append('image_file', file)
    if (caption.value.trim()) body.append('caption', caption.value.trim())

    const shot = await api.upload<Screenshot>(`/api/v1/projects/${slug}/screenshots`, body)
    data.value!.project.screenshots.push(shot)
    caption.value = ''
    notice.value = 'Скриншот загружен'
  }
  catch (err) {
    fail(err)
  }
  finally {
    uploading.value = false
    input.value = ''
  }
}

async function setCover(id: number) {
  clearMessages()

  try {
    await api.patch(`/api/v1/projects/${slug}/screenshots/${id}`, { screenshot: { is_cover: true } })
    data.value!.project.screenshots.forEach((shot) => {
      shot.is_cover = shot.id === id
    })
  }
  catch (err) {
    fail(err)
  }
}

async function deleteScreenshot(id: number) {
  if (!confirm('Удалить скриншот?')) return
  clearMessages()

  try {
    await api.del(`/api/v1/projects/${slug}/screenshots/${id}`)
    data.value!.project.screenshots = data.value!.project.screenshots.filter(shot => shot.id !== id)
  }
  catch (err) {
    fail(err)
  }
}

async function moveScreenshot(id: number, delta: number) {
  if (!project.value) return

  const ordered = [...project.value.screenshots].sort((a, b) => a.position - b.position)
  const index = ordered.findIndex(shot => shot.id === id)
  const target = index + delta
  if (index < 0 || target < 0 || target >= ordered.length) return

  const [item] = ordered.splice(index, 1)
  ordered.splice(target, 0, item!)

  clearMessages()

  try {
    const result = await api.put<{ items: Screenshot[] }>(`/api/v1/projects/${slug}/screenshots/order`, {
      ids: ordered.map(shot => shot.id),
    })
    data.value!.project.screenshots = result.items
  }
  catch (err) {
    fail(err)
  }
}

/* Downloads */

const downloadForm = reactive({ label: '', url: '', platform: 'windows', version: '' })

async function addDownload() {
  clearMessages()

  try {
    const download = await api.post<Download>(`/api/v1/projects/${slug}/downloads`, {
      download: {
        label: downloadForm.label.trim(),
        url: downloadForm.url.trim(),
        platform: downloadForm.platform || undefined,
        version: downloadForm.version.trim() || undefined,
      },
    })

    data.value!.project.downloads.push(download)
    downloadForm.label = ''
    downloadForm.url = ''
    downloadForm.version = ''
    notice.value = 'Ссылка добавлена'
  }
  catch (err) {
    fail(err)
  }
}

async function deleteDownload(id: number) {
  if (!confirm('Удалить ссылку?')) return
  clearMessages()

  try {
    await api.del(`/api/v1/projects/${slug}/downloads/${id}`)
    data.value!.project.downloads = data.value!.project.downloads.filter(item => item.id !== id)
  }
  catch (err) {
    fail(err)
  }
}

function toggleTag(slugValue: string) {
  selectedTags.value = selectedTags.value.includes(slugValue)
    ? selectedTags.value.filter(item => item !== slugValue)
    : [...selectedTags.value, slugValue]
}
</script>

<template>
  <div class="container">
    <div v-if="pending" class="empty mt-24">
      Загружаем проект…
    </div>

    <div v-else-if="loadError || !project" class="empty mt-24">
      Проект не найден.
      <div class="mt-16">
        <NuxtLink to="/dashboard" class="btn btn-ghost btn-sm">
          Назад
        </NuxtLink>
      </div>
    </div>

    <template v-else>
      <div class="page-head">
        <div>
          <div class="row mb-8">
            <span class="badge" :class="project.status === 'published' ? 'badge-published' : 'badge-draft'">
              {{ project.status === 'published' ? 'Опубликован' : 'Черновик' }}
            </span>
            <span class="muted small">{{ project.slug }}</span>
          </div>
          <h1>{{ project.title }}</h1>
        </div>

        <div class="row">
          <NuxtLink :to="`/p/${project.slug}`" class="btn btn-ghost btn-sm">
            Открыть страницу
          </NuxtLink>
          <button class="btn btn-ghost btn-sm" @click="togglePublish">
            {{ project.status === 'published' ? 'Снять с публикации' : 'Опубликовать' }}
          </button>
          <button class="btn btn-danger btn-sm" @click="removeProject">
            Удалить
          </button>
        </div>
      </div>

      <div v-if="error" class="form-error">
        {{ error }}
      </div>
      <div v-if="notice" class="form-success">
        {{ notice }}
      </div>

      <div class="editor-tabs">
        <button class="editor-tab" :class="{ active: tab === 'details' }" @click="tab = 'details'">
          Детали
        </button>
        <button class="editor-tab" :class="{ active: tab === 'screenshots' }" @click="tab = 'screenshots'">
          Скриншоты ({{ project.screenshots.length }})
        </button>
        <button class="editor-tab" :class="{ active: tab === 'downloads' }" @click="tab = 'downloads'">
          Ссылки ({{ project.downloads.length }})
        </button>
      </div>

      <div v-if="tab === 'details'" class="card card-pad" style="max-width: 720px;">
        <div class="field">
          <label class="label" for="title">Название</label>
          <input id="title" v-model="form.title" class="input" maxlength="120">
        </div>

        <div class="field">
          <label class="label" for="tagline">Короткое описание</label>
          <input id="tagline" v-model="form.tagline" class="input" maxlength="160">
        </div>

        <div class="field">
          <label class="label" for="kind">Тип</label>
          <select id="kind" v-model="form.kind" class="select">
            <option value="game">Игра</option>
            <option value="tool">Инструмент</option>
            <option value="asset">Ассет</option>
          </select>
        </div>

        <div class="field">
          <label class="label" for="description">Описание</label>
          <textarea id="description" v-model="form.description" class="textarea" maxlength="20000" />
        </div>

        <div class="field">
          <label class="label">Теги</label>
          <div class="row">
            <button
              v-for="tag in allTags"
              :key="tag.id"
              type="button"
              class="tag"
              :class="{ active: selectedTags.includes(tag.slug) }"
              @click="toggleTag(tag.slug)"
            >
              {{ tag.name }}
            </button>
          </div>
          <span class="hint">До 8 тегов.</span>
        </div>

        <button class="btn btn-primary" :disabled="saving" @click="save">
          {{ saving ? 'Сохраняем…' : 'Сохранить' }}
        </button>
      </div>

      <div v-else-if="tab === 'screenshots'" class="card card-pad">
        <div class="row-between mb-16">
          <div>
            <h2 class="section-title" style="margin-bottom: 4px;">
              Скриншоты
            </h2>
            <p class="muted small">
              JPEG, PNG или WebP, до 10 МБ. Первый скриншот становится обложкой.
            </p>
          </div>
        </div>

        <div class="row mb-24" style="align-items: flex-end;">
          <div class="field" style="margin-bottom: 0; min-width: 220px;">
            <label class="label" for="caption">Подпись <span class="muted">(необязательно)</span></label>
            <input id="caption" v-model="caption" class="input" maxlength="200" placeholder="Например, главный экран">
          </div>

          <label class="btn btn-primary" :class="{ disabled: uploading }">
            {{ uploading ? 'Загружаем…' : 'Загрузить файл' }}
            <input
              ref="fileInput"
              type="file"
              accept="image/jpeg,image/png,image/webp"
              hidden
              :disabled="uploading"
              @change="uploadScreenshot"
            >
          </label>
        </div>

        <div v-if="!project.screenshots.length" class="empty">
          Пока нет скриншотов.
        </div>

        <div v-else class="shot-grid">
          <div v-for="shot in [...project.screenshots].sort((a, b) => a.position - b.position)" :key="shot.id" class="shot-card">
            <img :src="shot.card_url || shot.url || ''" :alt="shot.caption || project.title">

            <div class="shot-actions">
              <button class="btn btn-ghost btn-sm" :disabled="shot.is_cover" @click="setCover(shot.id)">
                {{ shot.is_cover ? 'Обложка' : 'Сделать обложкой' }}
              </button>
              <button class="btn btn-ghost btn-icon btn-sm" title="Выше" @click="moveScreenshot(shot.id, -1)">
                ↑
              </button>
              <button class="btn btn-ghost btn-icon btn-sm" title="Ниже" @click="moveScreenshot(shot.id, 1)">
                ↓
              </button>
              <button class="btn btn-danger btn-sm" @click="deleteScreenshot(shot.id)">
                Удалить
              </button>
            </div>
          </div>
        </div>
      </div>

      <div v-else class="card card-pad">
        <h2 class="section-title">
          Ссылки на сборки
        </h2>
        <p class="muted small mb-24">
          Пока поддерживаются только внешние ссылки: Google Drive, Dropbox, собственный сайт.
          Ссылка должна начинаться с https://.
        </p>

        <div v-if="project.downloads.length" class="mb-24">
          <div v-for="item in project.downloads" :key="item.id" class="download-row">
            <div>
              <div class="download-label">
                {{ item.label }}
              </div>
              <div class="muted small">
                {{ [item.platform, item.version].filter(Boolean).join(' · ') }}
              </div>
            </div>
            <button class="btn btn-danger btn-sm" @click="deleteDownload(item.id)">
              Удалить
            </button>
          </div>
        </div>

        <div class="row" style="align-items: flex-end;">
          <div class="field" style="margin-bottom: 0; min-width: 180px;">
            <label class="label" for="dl-label">Название</label>
            <input id="dl-label" v-model="downloadForm.label" class="input" maxlength="80" placeholder="Windows build">
          </div>

          <div class="field" style="margin-bottom: 0; flex: 1; min-width: 240px;">
            <label class="label" for="dl-url">Ссылка</label>
            <input id="dl-url" v-model="downloadForm.url" class="input" type="url" placeholder="https://…">
          </div>

          <div class="field" style="margin-bottom: 0; min-width: 130px;">
            <label class="label" for="dl-platform">Платформа</label>
            <select id="dl-platform" v-model="downloadForm.platform" class="select">
              <option value="windows">Windows</option>
              <option value="macos">macOS</option>
              <option value="linux">Linux</option>
              <option value="web">Web</option>
              <option value="android">Android</option>
              <option value="other">Другое</option>
            </select>
          </div>

          <div class="field" style="margin-bottom: 0; min-width: 100px;">
            <label class="label" for="dl-version">Версия</label>
            <input id="dl-version" v-model="downloadForm.version" class="input" maxlength="40" placeholder="1.0">
          </div>

          <button class="btn btn-primary" @click="addDownload">
            Добавить
          </button>
        </div>
      </div>
    </template>
  </div>
</template>
