<script setup lang="ts">
import type { AiUsage, Me, StorageUsage } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

useSeoMeta({
  title: `Настройки — ${SITE_NAME}`,
  description: 'Какие проекты показывать в каталоге.',
})

const api = useApi()
const { user } = useAuth()

const { data: storage } = await useAsyncData(
  'me-storage',
  () => api.get<StorageUsage>('/api/v1/me/storage'),
)

const usedProjects = computed(() => storage.value?.projects.filter(project => project.used_bytes > 0) ?? [])

const form = reactive({
  show_nsfw: user.value?.show_nsfw ?? true,
  max_ai_usage: (user.value?.max_ai_usage ?? 'full') as AiUsage,
})

const aiLimitOptions: Array<{ value: AiUsage, label: string, hint: string }> = [
  {
    value: 'full',
    label: 'Любой уровень',
    hint: 'Показывать проекты с любым использованием ИИ.',
  },
  {
    value: 'significant',
    label: 'Не выше значительного',
    hint: 'Скрывать проекты, полностью сделанные ИИ.',
  },
  {
    value: 'partial',
    label: 'Не выше частичного',
    hint: 'Скрывать значительное и полное использование ИИ.',
  },
  {
    value: 'ai_free',
    label: 'Только AI-free',
    hint: 'Показывать только проекты без ИИ.',
  },
]

const saving = ref(false)
const error = ref('')
const notice = ref('')

const aiLimitHint = computed(() => aiLimitOptions.find(option => option.value === form.max_ai_usage)?.hint ?? '')

async function save() {
  error.value = ''
  notice.value = ''
  saving.value = true

  try {
    user.value = await api.patch<Me>('/api/v1/me/preferences', {
      user: {
        show_nsfw: form.show_nsfw,
        max_ai_usage: form.max_ai_usage,
      },
    })

    clearNuxtData()
    notice.value = 'Настройки сохранены'
  }
  catch (err) {
    error.value = formatApiError(err, 'Не удалось сохранить настройки')
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="container">
    <div class="page-head">
      <div>
        <h1>Настройки</h1>
        <p>Какие проекты показывать в каталоге и на страницах авторов.</p>
      </div>
    </div>

    <div v-if="error" class="form-error">
      {{ error }}
    </div>
    <div v-if="notice" class="form-success">
      {{ notice }}
    </div>

    <form class="card card-pad settings-card" @submit.prevent="save">
      <div class="field">
        <label class="check-row">
          <input v-model="form.show_nsfw" type="checkbox" aria-label="Показывать проекты 18+">
          <span>
            <span class="check-title">Показывать проекты 18+</span>
            <span class="hint">
              Проекты для взрослых не видны гостям. Выключите, чтобы скрыть их и у себя.
            </span>
          </span>
        </label>
      </div>

      <div class="field">
        <label class="label" for="max-ai-usage">Проекты с использованием ИИ</label>
        <select id="max-ai-usage" v-model="form.max_ai_usage" class="select">
          <option v-for="option in aiLimitOptions" :key="option.value" :value="option.value">
            {{ option.label }}
          </option>
        </select>
        <span class="hint">{{ aiLimitHint }}</span>
      </div>

      <button class="btn btn-primary" type="submit" :disabled="saving">
        {{ saving ? 'Сохраняем…' : 'Сохранить' }}
      </button>
    </form>

    <div v-if="storage" class="card card-pad settings-card mt-24">
      <h2 class="section-title">
        Хранилище
      </h2>
      <p class="muted small mb-16">
        Сборки, скриншоты и картинки в тексте. Файлы хранятся на сервере рядом с сайтом.
      </p>

      <div class="quota mb-16">
        <div class="quota-row">
          <span>Аккаунт</span>
          <span>{{ formatBytes(storage.used_bytes) }} из {{ formatBytes(storage.limit_bytes) }}</span>
        </div>
        <div class="quota-bar">
          <div class="quota-fill" :style="{ width: quotaPercent(storage.used_bytes, storage.limit_bytes) }" />
        </div>
      </div>

      <div v-if="usedProjects.length" class="quota">
        <div class="quota-row small">
          <span>По проектам</span>
          <span>сборки, до {{ formatBytes(storage.project_limit_bytes) }} на проект</span>
        </div>
        <div v-for="project in usedProjects" :key="project.slug" class="quota-row small">
          <NuxtLink :to="`/p/${project.slug}`">
            {{ project.title }}
          </NuxtLink>
          <span class="muted">{{ formatBytes(project.used_bytes) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
