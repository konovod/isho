<script setup lang="ts">
import type { ApiUser, ProjectCard } from '~/types/api'

const route = useRoute()
const api = useApi()
const { user } = useAuth()

const { data, error } = await useAsyncData(
  () => `profile-${route.params.username}:${user.value?.id ?? 'guest'}`,
  () => api.get<{ user: ApiUser, projects: ProjectCard[] }>(`/api/v1/users/${route.params.username}`),
)

if (!data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Пользователь не найден' })
}

const name = computed(() => data.value?.user.display_name || data.value?.user.username || '')
const initials = computed(() => name.value.slice(0, 2))

useSeoMeta({
  title: () => `${name.value} — ${SITE_NAME}`,
  description: () => data.value?.user.bio || `Проекты пользователя ${name.value}`,
})

const feedUrl = computed(() => `/api/v1/feeds/users/${data.value?.user.username}.rss`)
const feedTitle = computed(() => `${SITE_NAME} — проекты ${name.value}`)

useHead(() => ({
  link: data.value
    ? [{ rel: 'alternate', type: 'application/rss+xml', title: feedTitle.value, href: feedUrl.value }]
    : [],
}))
</script>

<template>
  <div v-if="data" class="container">
    <div class="page-head">
      <div class="row">
        <span class="avatar" style="width: 56px; height: 56px; font-size: 18px;">{{ initials }}</span>
        <div>
          <h1>{{ name }}</h1>
          <p>
            @{{ data.user.username }}
            <span
              v-if="data.user.ai_flair"
              class="forum-flair"
              title="Сгенерировано ИИ из последних сообщений автора"
            >
              <span aria-hidden="true">✦</span> {{ data.user.ai_flair }}
            </span>
          </p>
        </div>
      </div>

      <RssLink :href="feedUrl" :title="feedTitle" />
    </div>

    <p v-if="data.user.bio" class="muted mb-24" style="max-width: 640px;">
      {{ data.user.bio }}
    </p>

    <div v-if="!data.projects.length" class="empty">
      Пользователь пока не опубликовал ни одного проекта.
    </div>

    <div v-else class="grid">
      <ProjectCard v-for="project in data.projects" :key="project.id" :project="project" />
    </div>
  </div>
</template>
