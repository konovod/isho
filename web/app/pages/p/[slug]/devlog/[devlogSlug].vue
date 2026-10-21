<script setup lang="ts">
import type { Devlog, ProjectDetail } from '~/types/api'

const route = useRoute()
const api = useApi()
const { user } = useAuth()
const { date } = useFormat()

const slug = route.params.slug as string
const devlogSlug = route.params.devlogSlug as string

const { data } = await useAsyncData(
  `devlog-${slug}-${devlogSlug}`,
  async () => {
    const [project, devlog] = await Promise.all([
      api.get<ProjectDetail>(`/api/v1/projects/${slug}`),
      api.get<Devlog>(`/api/v1/projects/${slug}/devlogs/${devlogSlug}`),
    ])

    return { project, devlog }
  },
)

if (!data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Запись не найдена' })
}

const project = computed(() => data.value?.project ?? null)
const devlog = computed(() => data.value?.devlog ?? null)
const isOwner = computed(() => user.value?.id === project.value?.author.id)

useSeoMeta({
  title: () => `${devlog.value?.title} — ${project.value?.title} — ${SITE_NAME}`,
  description: () => markdownToText(devlog.value?.body).slice(0, 160),
  ogTitle: () => devlog.value?.title,
  ogDescription: () => markdownToText(devlog.value?.body).slice(0, 160),
  ogType: 'article',
})
</script>

<template>
  <div v-if="devlog && project" class="container">
    <div class="page-head">
      <div>
        <div class="row mb-8">
          <NuxtLink :to="`/p/${project.slug}`" class="muted small">
            ← {{ project.title }}
          </NuxtLink>
          <span class="badge badge-external">девлог</span>
        </div>

        <h1>{{ devlog.title }}</h1>
        <p class="muted small mt-8">
          {{ date(devlog.created_at) }}
        </p>
      </div>

      <NuxtLink
        v-if="isOwner"
        :to="`/dashboard/projects/${project.slug}/edit`"
        class="btn btn-ghost btn-sm"
      >
        Редактировать
      </NuxtLink>
    </div>

    <article class="card card-pad devlog-page">
      <MarkdownBody :source="devlog.body" />
    </article>

    <div class="mt-24">
      <NuxtLink :to="`/p/${project.slug}`" class="btn btn-ghost btn-sm">
        ← К проекту
      </NuxtLink>
    </div>
  </div>
</template>
