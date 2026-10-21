<script setup lang="ts">
import type { ProjectDetail } from '~/types/api'

const route = useRoute()
const api = useApi()
const { user } = useAuth()
const { date } = useFormat()

const { data: project, error } = await useAsyncData(
  `project-${route.params.slug}`,
  () => api.get<ProjectDetail>(`/api/v1/projects/${route.params.slug}`),
)

if (!project.value) {
  throw createError({ statusCode: 404, statusMessage: 'Проект не найден' })
}

const isOwner = computed(() => user.value?.id === project.value?.author.id)
const authorName = computed(() => project.value?.author.display_name || project.value?.author.username || '')
const kindLabel = computed(() => {
  const labels: Record<string, string> = { game: 'Игра', tool: 'Инструмент', asset: 'Ассет' }
  return labels[project.value?.kind ?? ''] ?? project.value?.kind ?? ''
})
const initials = computed(() => authorName.value.slice(0, 2))

useSeoMeta({
  title: () => `${project.value?.title} — isho`,
  description: () => project.value?.tagline || project.value?.description?.slice(0, 160) || '',
  ogTitle: () => project.value?.title,
  ogDescription: () => project.value?.tagline || '',
  ogImage: () => project.value?.cover_url || undefined,
})
</script>

<template>
  <div v-if="project">
    <div class="project-hero" :class="{ 'project-hero-empty': !project.cover_url }">
      <img v-if="project.cover_url" :src="project.cover_url" :alt="project.title">
    </div>

    <div class="container">
      <div class="project-head">
        <div>
          <div class="row mb-8">
            <span class="badge" :class="project.status === 'published' ? 'badge-published' : 'badge-draft'">
              {{ project.status === 'published' ? 'Опубликован' : 'Черновик' }}
            </span>
            <span class="muted small">{{ kindLabel }}</span>
          </div>

          <h1 class="project-title">
            {{ project.title }}
          </h1>

          <p v-if="project.tagline" class="muted" style="margin-top: 8px; font-size: 17px;">
            {{ project.tagline }}
          </p>
        </div>

        <div v-if="isOwner" class="row" style="margin-left: auto;">
          <NuxtLink :to="`/dashboard/projects/${project.slug}/edit`" class="btn btn-ghost btn-sm">
            Редактировать
          </NuxtLink>
        </div>
      </div>

      <div class="project-layout">
        <div>
          <ScreenshotGallery
            v-if="project.screenshots.length"
            :screenshots="project.screenshots"
            :title="project.title"
          />

          <section class="section" style="padding-top: 22px;">
            <h2 class="section-title">
              Об игре
            </h2>
            <p class="description">
              {{ project.description || 'Автор пока не добавил описание.' }}
            </p>
          </section>

          <DownloadList class="mt-24" :downloads="project.downloads" />
        </div>

        <aside class="project-sidebar">
          <div class="card card-pad">
            <div class="author-card">
              <span class="avatar">{{ initials }}</span>
              <div>
                <NuxtLink :to="`/u/${project.author.username}`" style="font-weight: 650;">
                  {{ authorName }}
                </NuxtLink>
                <div class="muted small">
                  @{{ project.author.username }}
                </div>
              </div>
            </div>

            <div v-if="project.author.bio" class="muted small mt-16">
              {{ project.author.bio }}
            </div>
          </div>

          <div v-if="project.tags.length" class="card card-pad">
            <h3 class="section-title" style="font-size: 14px;">
              Теги
            </h3>
            <div class="row">
              <NuxtLink
                v-for="tag in project.tags"
                :key="tag.id"
                :to="`/?tag=${tag.slug}`"
                class="tag"
              >
                {{ tag.name }}
              </NuxtLink>
            </div>
          </div>

          <div class="card card-pad">
            <div class="row-between small muted">
              <span>Опубликован</span>
              <span>{{ date(project.published_at) }}</span>
            </div>
          </div>
        </aside>
      </div>
    </div>
  </div>
</template>
