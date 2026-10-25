<script setup lang="ts">
import type { JamEntry, ProjectCard } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = defineProps<{
  jamSlug: string
}>()

const emit = defineEmits<{
  submitted: [entry: JamEntry]
  cancel: []
}>()

const api = useApi()

const { data, pending, error: loadError } = await useAsyncData(
  `jam-eligible-${props.jamSlug}`,
  () => api.get<{ items: ProjectCard[] }>(`/api/v1/jams/${props.jamSlug}/eligible_projects`),
)

const projects = computed(() => data.value?.items ?? [])
const selected = ref('')
const submitting = ref(false)
const error = ref('')

async function submit() {
  if (!selected.value || submitting.value) return

  error.value = ''
  submitting.value = true

  try {
    const entry = await api.post<JamEntry>(`/api/v1/jams/${props.jamSlug}/entries`, {
      jam_entry: { project_slug: selected.value },
    })
    emit('submitted', entry)
  }
  catch (err) {
    error.value = formatApiError(err)
  }
  finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="card card-pad jam-submit">
    <div class="row-between mb-16">
      <h2 class="section-title" style="margin-bottom: 0;">
        Подать заявку
      </h2>
      <button class="btn btn-ghost btn-sm" type="button" @click="emit('cancel')">
        Закрыть
      </button>
    </div>

    <div v-if="error" class="form-error">
      {{ error }}
    </div>

    <div v-if="pending" class="empty">
      Загружаем проекты…
    </div>

    <div v-else-if="loadError" class="empty">
      Не удалось загрузить проекты.
    </div>

    <div v-else-if="!projects.length" class="empty">
      Нет опубликованных проектов без заявки в этот джем.
      <div class="mt-16">
        <NuxtLink to="/dashboard/projects/new" class="btn btn-primary btn-sm">
          Создать проект
        </NuxtLink>
      </div>
    </div>

    <template v-else>
      <div class="jam-project-picker">
        <button
          v-for="project in projects"
          :key="project.id"
          type="button"
          class="jam-project-option"
          :class="{ active: selected === project.slug }"
          @click="selected = project.slug"
        >
          <span class="jam-project-cover">
            <img v-if="project.cover_url" :src="project.cover_url" :alt="project.title">
            <span v-else>{{ project.title.slice(0, 2) }}</span>
          </span>
          <span class="jam-project-info">
            <strong>{{ project.title }}</strong>
            <span v-if="project.tagline" class="muted small">{{ project.tagline }}</span>
          </span>
        </button>
      </div>

      <div class="row mt-16">
        <button class="btn btn-primary" type="button" :disabled="!selected || submitting" @click="submit">
          {{ submitting ? 'Подаём…' : 'Подать заявку' }}
        </button>
      </div>
    </template>
  </div>
</template>
