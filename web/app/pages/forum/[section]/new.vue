<script setup lang="ts">
import type { ForumSection, ForumTopic } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const route = useRoute()
const api = useApi()

const sectionSlug = computed(() => route.params.section as string)
const form = reactive({ title: '', body: '' })
const saving = ref(false)
const error = ref('')

const { data: section } = await useAsyncData(
  `forum-new-topic-section-${sectionSlug.value}`,
  () => api.get<{ section: ForumSection }>(`/api/v1/forum/sections/${sectionSlug.value}`),
)

if (!section.value) {
  throw createError({ statusCode: 404, statusMessage: 'Раздел не найден' })
}

useSeoMeta({
  title: () => `Новая тема — ${section.value?.section.title || 'Форум'} — isho`,
})

async function submit() {
  if (!form.title.trim()) {
    error.value = 'Укажите название темы.'
    return
  }

  if (!form.body.trim()) {
    error.value = 'Добавьте текст первого сообщения.'
    return
  }

  saving.value = true
  error.value = ''

  try {
    const topic = await api.post<ForumTopic>(`/api/v1/forum/sections/${sectionSlug.value}/topics`, {
      forum_topic: {
        title: form.title.trim(),
        body: form.body.trim(),
      },
    })

    await navigateTo(`/forum/${topic.section.slug}/${topic.slug}`)
  }
  catch (err) {
    error.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="container">
    <div class="row mb-16">
      <NuxtLink :to="`/forum/${sectionSlug}`" class="muted small">
        ← {{ section?.section.title || 'Раздел' }}
      </NuxtLink>
    </div>

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
