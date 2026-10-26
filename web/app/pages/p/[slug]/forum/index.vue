<script setup lang="ts">
import type { ForumMeta, ForumTopic, ProjectDetail } from '~/types/api'

interface ProjectForumResponse {
  items: ForumTopic[]
  meta: ForumMeta
}

const route = useRoute()
const api = useApi()
const { user } = useAuth()

const slug = computed(() => route.params.slug as string)
const page = computed(() => Math.max(1, Number(route.query.page) || 1))
const userKey = computed(() => user.value?.id ?? 'guest')

const { data: project } = await useAsyncData(
  `project-forum-project-${slug.value}`,
  () => api.get<ProjectDetail>(`/api/v1/projects/${slug.value}`),
)

const { data, pending } = await useAsyncData(
  () => `project-forum-${slug.value}-${userKey.value}`,
  () => api.get<ProjectForumResponse>(`/api/v1/projects/${slug.value}/forum/topics?page=${page.value}`),
  { watch: [page, slug, userKey] },
)

if (!project.value) {
  throw createError({ statusCode: 404, statusMessage: 'Проект не найден' })
}

const topics = computed(() => data.value?.items ?? [])

useSeoMeta({
  title: () => `Обсуждение «${project.value?.title}» — ${SITE_NAME}`,
  description: () => `Вопросы и ответы по проекту ${project.value?.title}.`,
})
</script>

<template>
  <div v-if="project" class="container forum-page">
    <nav class="forum-crumbs" aria-label="Хлебные крошки">
      <NuxtLink to="/forum">Форум</NuxtLink>
      <span class="forum-crumb-sep" aria-hidden="true">›</span>
      <NuxtLink :to="`/p/${project.slug}`">{{ project.title }}</NuxtLink>
      <span class="forum-crumb-sep" aria-hidden="true">›</span>
      <span>Обсуждение</span>
    </nav>

    <div class="page-head">
      <div>
        <h1>Обсуждение проекта</h1>
        <p>{{ project.title }} · вопросы и ответы</p>
      </div>

      <NuxtLink
        v-if="user"
        :to="`/p/${project.slug}/forum/new`"
        class="btn btn-primary"
      >
        + Задать вопрос
      </NuxtLink>
      <NuxtLink v-else to="/sign_in" class="btn btn-ghost">
        Войти, чтобы спросить
      </NuxtLink>
    </div>

    <div v-if="pending" class="empty">
      Загружаем темы…
    </div>

    <div v-else-if="!topics.length" class="empty">
      Вопросов пока нет. Задайте первый — автор увидит его в обсуждении проекта.
    </div>

    <template v-else>
      <ForumTopicList :topics="topics" :show-project="false" />

      <ForumPagination
        :page="data?.meta.page || 1"
        :pages="data?.meta.pages || 1"
        :base-path="`/p/${project.slug}/forum`"
      />
    </template>
  </div>
</template>
