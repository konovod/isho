<script setup lang="ts">
import type { AdminUser, AdminUserList, ProjectCard, ProjectList } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: ['auth', 'admin'] })

useSeoMeta({
  title: `Модерация — ${SITE_NAME}`,
  description: 'Удаление пользователей и снятие проектов с публикации.',
})

const api = useApi()
const { user } = useAuth()
const { plural } = useFormat()

const tab = ref<'users' | 'projects'>('users')
const notice = ref('')
const actionError = ref('')

const userSearch = ref('')
const userQuery = ref('')
const usersPage = ref(1)

const {
  data: usersData,
  pending: usersPending,
  error: usersLoadError,
  refresh: refreshUsers,
} = await useAsyncData(
  'admin-users',
  () => api.get<AdminUserList>('/api/v1/admin/users', {
    q: userQuery.value || undefined,
    page: usersPage.value,
    per_page: 50,
  }),
  { watch: [userQuery] },
)

const users = computed(() => usersData.value?.items ?? [])
const usersTotal = computed(() => usersData.value?.meta.total ?? 0)

const projectSearch = ref('')
const projectQuery = ref('')
const projectsPage = ref(1)

const {
  data: projectsData,
  pending: projectsPending,
  error: projectsLoadError,
  refresh: refreshProjects,
} = await useAsyncData(
  'admin-projects',
  () => api.get<ProjectList>('/api/v1/projects', {
    q: projectQuery.value || undefined,
    page: projectsPage.value,
    per_page: 48,
  }),
  { watch: [projectQuery] },
)

const projects = computed(() => projectsData.value?.items ?? [])
const projectsTotal = computed(() => projectsData.value?.meta.total ?? 0)

function searchUsers() {
  usersPage.value = 1
  userQuery.value = userSearch.value.trim()
}

function searchProjects() {
  projectsPage.value = 1
  projectQuery.value = projectSearch.value.trim()
}

async function removeUser(item: AdminUser) {
  if (item.id === user.value?.id) return

  const count = `${item.projects_count} ${plural(item.projects_count, 'проект', 'проекта', 'проектов')}`

  if (!confirm(`Удалить @${item.username} вместе с ${count}? Это действие необратимо.`)) return

  notice.value = ''
  actionError.value = ''

  try {
    await api.del(`/api/v1/admin/users/${item.username}`)
    notice.value = `Пользователь @${item.username} удалён`
    await refreshUsers()
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
}

async function onProjectModerated(_project: ProjectCard) {
  notice.value = 'Проект снят с публикации. Причина сохранена и видна автору.'
  actionError.value = ''
  await refreshProjects()
}
</script>

<template>
  <div class="container">
    <div class="page-head">
      <div>
        <h1>Модерация</h1>
        <p>Удаление пользователей и снятие проектов с публикации.</p>
      </div>
    </div>

    <div v-if="actionError" class="form-error">
      {{ actionError }}
    </div>
    <div v-if="notice" class="form-success">
      {{ notice }}
    </div>

    <div class="editor-tabs">
      <button class="editor-tab" :class="{ active: tab === 'users' }" @click="tab = 'users'">
        Пользователи
      </button>
      <button class="editor-tab" :class="{ active: tab === 'projects' }" @click="tab = 'projects'">
        Проекты
      </button>
    </div>

    <section v-if="tab === 'users'">
      <form class="search-row" @submit.prevent="searchUsers">
        <input
          v-model="userSearch"
          class="input"
          type="search"
          placeholder="username, email или имя"
          aria-label="Поиск пользователей"
        >
        <button class="btn btn-ghost" type="submit">
          Найти
        </button>
      </form>

      <div v-if="usersPending" class="empty">
        Загружаем пользователей…
      </div>

      <div v-else-if="usersLoadError" class="empty">
        Не удалось загрузить пользователей.
        <button class="btn btn-ghost btn-sm mt-16" @click="refreshUsers()">
          Повторить
        </button>
      </div>

      <div v-else-if="!users.length" class="empty">
        Пользователей не нашли.
      </div>

      <div v-else class="dash-list">
        <div v-for="item in users" :key="item.id" class="dash-row">
          <div class="dash-info">
            <div class="row mb-8">
              <h3>{{ item.display_name || item.username }}</h3>
              <span v-if="item.is_admin" class="badge badge-external">админ</span>
            </div>
            <div class="muted small">
              @{{ item.username }} · {{ item.email }} ·
              {{ item.projects_count }} {{ plural(item.projects_count, 'проект', 'проекта', 'проектов') }}
            </div>
          </div>

          <div class="dash-actions">
            <NuxtLink :to="`/u/${item.username}`" class="btn btn-ghost btn-sm">
              Профиль
            </NuxtLink>
            <button
              class="btn btn-danger btn-sm"
              type="button"
              :disabled="item.id === user?.id"
              :title="item.id === user?.id ? 'Нельзя удалить свой аккаунт' : undefined"
              @click="removeUser(item)"
            >
              Удалить
            </button>
          </div>
        </div>
      </div>

      <p v-if="usersTotal > users.length" class="muted small mt-16">
        Показаны первые {{ users.length }} из {{ usersTotal }}.
      </p>
    </section>

    <section v-else>
      <form class="search-row" @submit.prevent="searchProjects">
        <input
          v-model="projectSearch"
          class="input"
          type="search"
          placeholder="Поиск по названию проекта…"
          aria-label="Поиск проектов"
        >
        <button class="btn btn-ghost" type="submit">
          Найти
        </button>
      </form>

      <div v-if="projectsPending" class="empty">
        Загружаем проекты…
      </div>

      <div v-else-if="projectsLoadError" class="empty">
        Не удалось загрузить проекты.
        <button class="btn btn-ghost btn-sm mt-16" @click="refreshProjects()">
          Повторить
        </button>
      </div>

      <div v-else-if="!projects.length" class="empty">
        Опубликованных проектов не нашли.
      </div>

      <div v-else class="moderation-projects">
        <div v-for="item in projects" :key="item.id" class="card card-pad">
          <div class="row-between moderation-project-head">
            <div class="row">
              <div class="dash-thumb">
                <img v-if="item.cover_url" :src="item.cover_url" :alt="item.title">
              </div>
              <div>
                <h3>{{ item.title }}</h3>
                <div class="muted small">
                  @{{ item.author.username }}
                  <template v-if="item.tags.length">
                    · {{ item.tags.map(tag => tag.name).join(', ') }}
                  </template>
                </div>
              </div>
            </div>

            <NuxtLink :to="`/p/${item.slug}`" class="btn btn-ghost btn-sm">
              Открыть
            </NuxtLink>
          </div>

          <div class="mt-16">
            <ModerationUnpublish :slug="item.slug" @done="onProjectModerated" />
          </div>
        </div>
      </div>

      <p v-if="projectsTotal > projects.length" class="muted small mt-16">
        Показаны первые {{ projects.length }} из {{ projectsTotal }}.
      </p>
    </section>
  </div>
</template>
