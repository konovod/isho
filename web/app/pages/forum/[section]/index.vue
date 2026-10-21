<script setup lang="ts">
import type { ForumMeta, ForumSection, ForumTopic } from '~/types/api'

interface SectionResponse {
  section: ForumSection
  items: ForumTopic[]
  meta: ForumMeta
}

const route = useRoute()
const api = useApi()
const { user } = useAuth()

const sectionSlug = computed(() => route.params.section as string)
const page = computed(() => Math.max(1, Number(route.query.page) || 1))

const { data, pending, error } = await useAsyncData(
  `forum-section-${sectionSlug.value}`,
  () => api.get<SectionResponse>(`/api/v1/forum/sections/${sectionSlug.value}?page=${page.value}`),
  { watch: [page, sectionSlug] },
)

const section = computed(() => data.value?.section ?? null)
const topics = computed(() => data.value?.items ?? [])

if (!data.value && error.value) {
  throw createError({ statusCode: 404, statusMessage: 'Раздел не найден' })
}

useSeoMeta({
  title: () => `${section.value?.title || 'Форум'} — isho`,
  description: () => section.value?.description || 'Форум isho',
})
</script>

<template>
  <div v-if="section" class="container">
    <div class="row mb-16">
      <NuxtLink to="/forum" class="muted small">
        ← Форум
      </NuxtLink>
    </div>

    <div class="page-head">
      <div>
        <h1>{{ section.title }}</h1>
        <p v-if="section.description">
          {{ section.description }}
        </p>
      </div>

      <NuxtLink
        v-if="user && section.slug !== 'projects'"
        :to="`/forum/${section.slug}/new`"
        class="btn btn-primary"
      >
        + Новая тема
      </NuxtLink>
      <span
        v-else-if="section.slug === 'projects'"
        class="muted small"
      >
        Темы создаются на страницах проектов
      </span>
      <NuxtLink v-else to="/sign_in" class="btn btn-ghost">
        Войти, чтобы создать тему
      </NuxtLink>
    </div>

    <div v-if="pending" class="empty">
      Загружаем темы…
    </div>

    <div v-else-if="!topics.length" class="empty">
      Пока нет тем. Начните обсуждение первым.
    </div>

    <template v-else>
      <ForumTopicList :topics="topics" />

      <ForumPagination
        :page="data?.meta.page || 1"
        :pages="data?.meta.pages || 1"
        :base-path="`/forum/${section.slug}`"
      />
    </template>
  </div>
</template>
