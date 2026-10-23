<script setup lang="ts">
import type { AdminBlockedEmail, AdminBlockedEmailList, AdminUser, AdminUserList, ProjectCard, ProjectList } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: ['auth', 'admin'] })

useSeoMeta({
  title: `Модерация — ${SITE_NAME}`,
  description: 'Удаление пользователей, чёрный список почт, снятие проектов с публикации и разделы форума.',
})

const api = useApi()
const { user } = useAuth()
const { date, plural } = useFormat()

const tab = ref<'users' | 'projects' | 'forum' | 'blocked'>('users')
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

const blockedSearch = ref('')
const blockedQuery = ref('')
const blockedPage = ref(1)

const {
  data: blockedData,
  pending: blockedPending,
  error: blockedLoadError,
  refresh: refreshBlocked,
} = await useAsyncData(
  'admin-blocked-emails',
  () => api.get<AdminBlockedEmailList>('/api/v1/admin/blocked_emails', {
    q: blockedQuery.value || undefined,
    page: blockedPage.value,
    per_page: 50,
  }),
  { watch: [blockedQuery] },
)

const blockedEmails = computed(() => blockedData.value?.items ?? [])
const blockedTotal = computed(() => blockedData.value?.meta.total ?? 0)

function searchUsers() {
  usersPage.value = 1
  userQuery.value = userSearch.value.trim()
}

function searchProjects() {
  projectsPage.value = 1
  projectQuery.value = projectSearch.value.trim()
}

function searchBlocked() {
  blockedPage.value = 1
  blockedQuery.value = blockedSearch.value.trim()
}

async function removeUser(item: AdminUser) {
  if (item.id === user.value?.id) return

  const count = `${item.projects_count} ${plural(item.projects_count, 'проект', 'проекта', 'проектов')}`

  if (!confirm(`Удалить @${item.username} вместе с ${count}? Почта попадёт в чёрный список, и зарегистрироваться с ней снова будет нельзя. Это действие необратимо.`)) return

  notice.value = ''
  actionError.value = ''

  try {
    await api.del(`/api/v1/admin/users/${item.username}`)
    notice.value = `Пользователь @${item.username} удалён, почта добавлена в чёрный список`
    await Promise.all([refreshUsers(), refreshBlocked()])
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
}

async function unblockEmail(item: AdminBlockedEmail) {
  if (!confirm(`Разблокировать ${item.email}? Адрес снова можно будет использовать для регистрации.`)) return

  notice.value = ''
  actionError.value = ''

  try {
    await api.del(`/api/v1/admin/blocked_emails/${item.id}`)
    notice.value = `Адрес ${item.email} разблокирован`
    await refreshBlocked()
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
}

async function onUserChanged(updated: AdminUser) {
  notice.value = updated.ban
    ? `Пользователь @${updated.username} забанен до ${date(updated.ban.banned_until)}`
    : `Бан с @${updated.username} снят`
  actionError.value = ''
  await refreshUsers()
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
        <p>Удаление пользователей, чёрный список почт, снятие проектов с публикации и разделы форума.</p>
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
      <button class="editor-tab" :class="{ active: tab === 'blocked' }" @click="tab = 'blocked'">
        Чёрный список
      </button>
      <button class="editor-tab" :class="{ active: tab === 'forum' }" @click="tab = 'forum'">
        Форум
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

            <ModerationBan :user="item" class="mt-16" @done="onUserChanged" />
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

    <section v-else-if="tab === 'projects'">
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

    <section v-else-if="tab === 'forum'">
      <ForumSectionsAdmin />
    </section>

    <section v-else>
      <p class="muted small mb-16">
        Сюда попадают почты удалённых аккаунтов. Пока адрес в списке, зарегистрироваться с ним нельзя.
      </p>

      <form class="search-row" @submit.prevent="searchBlocked">
        <input
          v-model="blockedSearch"
          class="input"
          type="search"
          placeholder="почта или ник удалённого аккаунта"
          aria-label="Поиск в чёрном списке"
        >
        <button class="btn btn-ghost" type="submit">
          Найти
        </button>
      </form>

      <div v-if="blockedPending" class="empty">
        Загружаем чёрный список…
      </div>

      <div v-else-if="blockedLoadError" class="empty">
        Не удалось загрузить чёрный список.
        <button class="btn btn-ghost btn-sm mt-16" @click="refreshBlocked()">
          Повторить
        </button>
      </div>

      <div v-else-if="!blockedEmails.length" class="empty">
        Чёрный список пуст.
      </div>

      <div v-else class="dash-list">
        <div v-for="item in blockedEmails" :key="item.id" class="dash-row">
          <div class="dash-info">
            <h3>{{ item.email }}</h3>
            <div class="muted small">
              <template v-if="item.username">@{{ item.username }} · </template>
              заблокирован {{ date(item.created_at) }}
            </div>
          </div>

          <div class="dash-actions">
            <button class="btn btn-ghost btn-sm" type="button" @click="unblockEmail(item)">
              Разблокировать
            </button>
          </div>
        </div>
      </div>

      <p v-if="blockedTotal > blockedEmails.length" class="muted small mt-16">
        Показаны первые {{ blockedEmails.length }} из {{ blockedTotal }}.
      </p>
    </section>
  </div>
</template>
