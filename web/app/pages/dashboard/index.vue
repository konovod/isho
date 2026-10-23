<script setup lang="ts">
import type { ProjectDetail } from '~/types/api'

definePageMeta({ middleware: 'auth' })

const api = useApi()
const { plural } = useFormat()

const { data, pending, error, refresh } = await useAsyncData(
  'my-projects',
  () => api.get<{ items: ProjectDetail[] }>('/api/v1/me/projects'),
)

const projects = computed(() => data.value?.items ?? [])
</script>

<template>
  <div class="container">
    <div class="page-head">
      <div>
        <h1>Мои проекты</h1>
        <p>Черновики видны только вам. Опубликованные попадают в каталог.</p>
      </div>

      <NuxtLink to="/dashboard/projects/new" class="btn btn-primary">
        + Новый проект
      </NuxtLink>
    </div>

    <div v-if="pending" class="empty">
      Загружаем…
    </div>

    <div v-else-if="error" class="empty">
      Не удалось загрузить проекты.
      <button class="btn btn-ghost btn-sm mt-16" @click="refresh()">
        Повторить
      </button>
    </div>

    <div v-else-if="!projects.length" class="empty">
      Здесь пока ничего нет. Создайте первый проект — это займёт минуту.
      <div class="mt-16">
        <NuxtLink to="/dashboard/projects/new" class="btn btn-primary btn-sm">
          Создать проект
        </NuxtLink>
      </div>
    </div>

    <div v-else class="dash-list">
      <div v-for="project in projects" :key="project.id" class="dash-row">
        <div class="dash-thumb">
          <img v-if="project.cover_url" :src="project.cover_url" :alt="project.title">
        </div>

        <div class="dash-info">
          <div class="row mb-8">
            <h3>{{ project.title }}</h3>
            <span class="badge" :class="project.status === 'published' ? 'badge-published' : 'badge-draft'">
              {{ project.status === 'published' ? 'Опубликован' : 'Черновик' }}
            </span>
          </div>
          <div class="muted small">
            {{ project.screenshots.length }}
            {{ plural(project.screenshots.length, 'скриншот', 'скриншота', 'скриншотов') }}
            · {{ project.downloads.length }}
            {{ plural(project.downloads.length, 'ссылка', 'ссылки', 'ссылок') }}
            · {{ project.builds.length }}
            {{ plural(project.builds.length, 'сборка', 'сборки', 'сборок') }}
          </div>
        </div>

        <div class="dash-actions">
          <NuxtLink :to="`/p/${project.slug}`" class="btn btn-ghost btn-sm">
            Открыть
          </NuxtLink>
          <NuxtLink :to="`/dashboard/projects/${project.slug}/edit`" class="btn btn-ghost btn-sm">
            Редактировать
          </NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>
