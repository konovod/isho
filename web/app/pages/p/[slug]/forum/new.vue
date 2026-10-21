<script setup lang="ts">
import type { ForumTopic, ProjectDetail } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const route = useRoute()
const api = useApi()

const slug = computed(() => route.params.slug as string)
const form = reactive({ title: '', body: '' })
const saving = ref(false)
const error = ref('')

const { data: project } = await useAsyncData(
  `project-forum-new-${slug.value}`,
  () => api.get<ProjectDetail>(`/api/v1/projects/${slug.value}`),
)

if (!project.value) {
  throw createError({ statusCode: 404, statusMessage: 'Проект не найден' })
}

useSeoMeta({
  title: () => `Новая тема — ${project.value?.title || 'Проект'} — isho`,
})

async function submit() {
  if (!form.title.trim()) {
    error.value = 'Укажите название темы.'
    return
  }

  if (!form.body.trim()) {
    error.value = 'Добавьте текст вопроса.'
    return
  }

  saving.value = true
  error.value = ''

  try {
    const topic = await api.post<ForumTopic>(`/api/v1/projects/${slug.value}/forum/topics`, {
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
      <NuxtLink :to="`/p/${slug}/forum`" class="muted small">
        ← Обсуждение проекта
      </NuxtLink>
    </div>

    <div class="page-head">
      <div>
        <h1>Новая тема</h1>
        <p>{{ project?.title }} · вопрос или предложение</p>
      </div>
    </div>

    <div class="card card-pad forum-topic-form">
      <div v-if="error" class="form-error">
        {{ error }}
      </div>

      <div class="field">
        <label class="label" for="project-forum-title">Название</label>
        <input
          id="project-forum-title"
          v-model="form.title"
          class="input"
          maxlength="160"
          placeholder="Например: как запустить прототип?"
        >
      </div>

      <div class="field">
        <label class="label" for="project-forum-body">Вопрос</label>
        <MarkdownEditor
          id="project-forum-body"
          v-model="form.body"
          :rows="12"
          :maxlength="20000"
          placeholder="Опишите вопрос подробнее…"
        />
      </div>

      <div class="row">
        <button class="btn btn-primary" :disabled="saving" @click="submit">
          {{ saving ? 'Создаём…' : 'Создать тему' }}
        </button>
        <NuxtLink :to="`/p/${slug}/forum`" class="btn btn-ghost">
          Отмена
        </NuxtLink>
      </div>
    </div>
  </div>
</template>
