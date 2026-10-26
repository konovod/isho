<script setup lang="ts">
import type { ApiUser, ProfileStats, ProjectCard } from '~/types/api'

const route = useRoute()
const api = useApi()
const { user, emailConfirmed, banned, impersonating } = useAuth()
const { plural } = useFormat()

const { data, error } = await useAsyncData(
  () => `profile-${route.params.username}:${user.value?.id ?? 'guest'}`,
  () => api.get<{ user: ApiUser, stats: ProfileStats, projects: ProjectCard[] }>(`/api/v1/users/${route.params.username}`),
)

if (!data.value) {
  throw createError({ statusCode: 404, statusMessage: 'Пользователь не найден' })
}

const name = computed(() => data.value?.user.display_name || data.value?.user.username || '')
const initials = computed(() => name.value.slice(0, 2))

const canMessage = computed(() => {
  const viewer = user.value
  const profile = data.value?.user
  if (!viewer || !profile) return false
  if (viewer.id === profile.id) return false
  if (!emailConfirmed.value || banned.value || impersonating.value) return false

  return true
})

interface ProfileStat {
  key: string
  value: number
  label: string
  title?: string
}

const stats = computed<ProfileStat[]>(() => {
  const value = data.value?.stats
  if (!value) return []

  const received = value.likes_received_count

  return [
    {
      key: 'projects',
      value: value.projects_count,
      label: plural(value.projects_count, 'проект', 'проекта', 'проектов'),
    },
    {
      key: 'comments',
      value: value.comments_count,
      label: plural(value.comments_count, 'комментарий', 'комментария', 'комментариев'),
    },
    {
      key: 'likes-given',
      value: value.likes_given_count,
      label: `${plural(value.likes_given_count, 'лайк', 'лайка', 'лайков')} поставлено`,
    },
    {
      key: 'likes-received',
      value: received,
      label: `${plural(Math.abs(received), 'лайк', 'лайка', 'лайков')} получено`,
      title: 'Лайки на сообщения минус дизлайки',
    },
  ]
})

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

      <NuxtLink
        v-if="canMessage"
        :to="`/messages/${data.user.username}`"
        class="btn btn-primary btn-sm"
      >
        Переписка
      </NuxtLink>
    </div>

    <p v-if="data.user.bio" class="muted mb-24" style="max-width: 640px;">
      {{ data.user.bio }}
    </p>

    <p v-if="stats.length" class="profile-stats">
      <span v-for="stat in stats" :key="stat.key" class="profile-stat" :title="stat.title">
        <strong>{{ stat.value }}</strong> {{ stat.label }}
      </span>
    </p>

    <div v-if="!data.projects.length" class="empty">
      Пользователь пока не опубликовал ни одного проекта.
    </div>

    <div v-else class="grid">
      <ProjectCard v-for="project in data.projects" :key="project.id" :project="project" />
    </div>
  </div>
</template>
