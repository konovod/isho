<script setup lang="ts">
import type { ApiUser, ProfileStats, ProjectCard } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

interface ProfileResponse {
  user: ApiUser
  stats: ProfileStats
  projects: ProjectCard[]
  /** Only the blocker sees this flag; the blocked account always gets false. */
  blocked: boolean
}

const route = useRoute()
const api = useApi()
const { user, emailConfirmed, banned, impersonating } = useAuth()
const { setUnreadCount } = useMessages()
const { plural } = useFormat()

const { data, error } = await useAsyncData(
  () => `profile-${route.params.username}:${user.value?.id ?? 'guest'}`,
  () => api.get<ProfileResponse>(`/api/v1/users/${route.params.username}`),
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

const isSelf = computed(() => !!user.value && user.value.id === data.value?.user.id)
const canBlock = computed(() => !!user.value && !isSelf.value && !impersonating.value)
const blocked = computed(() => data.value?.blocked === true)

const blocking = ref(false)
const blockError = ref('')

async function toggleBlock() {
  const current = data.value
  if (!current || !user.value || isSelf.value || impersonating.value) return

  const next = !blocked.value
  if (next && !confirm(`Заблокировать ${name.value}? Пользователя не будет видно на форуме, а его личные сообщения перестанут приходить.`)) return

  blocking.value = true
  blockError.value = ''

  try {
    const path = `/api/v1/users/${encodeURIComponent(current.user.username)}/block`
    const result = next
      ? await api.post<{ unread_messages_count: number }>(path)
      : await api.del<{ unread_messages_count: number }>(path)

    setUnreadCount(result.unread_messages_count)
    data.value = { ...current, blocked: next }
    clearNuxtData()
  }
  catch (err) {
    blockError.value = formatApiError(err, 'Не удалось изменить блокировку')
  }
  finally {
    blocking.value = false
  }
}

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

      <div class="row">
        <RssLink :href="feedUrl" :title="feedTitle" />

        <NuxtLink
          v-if="canMessage && !blocked"
          :to="`/messages/${data.user.username}`"
          class="btn btn-primary btn-sm"
        >
          Переписка
        </NuxtLink>

        <button
          v-if="canBlock"
          class="btn btn-ghost btn-sm"
          type="button"
          :disabled="blocking"
          @click="toggleBlock"
        >
          {{ blocked ? 'Разблокировать' : 'Заблокировать' }}
        </button>
      </div>
    </div>

    <div v-if="blockError" class="form-error">
      {{ blockError }}
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
