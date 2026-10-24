<script setup lang="ts">
import type { ForumMeta, ForumSection, ForumTopic } from '~/types/api'

interface SectionResponse {
  section: ForumSection
  children: ForumSection[]
  items: ForumTopic[]
  meta: ForumMeta
}

const route = useRoute()
const api = useApi()
const { user } = useAuth()

const sectionSlug = computed(() => route.params.section as string)
const page = computed(() => Math.max(1, Number(route.query.page) || 1))
const userKey = computed(() => user.value?.id ?? 'guest')

const { data, pending, error } = await useAsyncData(
  () => `forum-section-${sectionSlug.value}-${userKey.value}`,
  () => api.get<SectionResponse>(`/api/v1/forum/sections/${sectionSlug.value}?page=${page.value}`),
  { watch: [page, sectionSlug, userKey] },
)

const section = computed(() => data.value?.section ?? null)
const children = computed(() => data.value?.children ?? [])
const topics = computed(() => data.value?.items ?? [])

if (!data.value && error.value) {
  throw createError({ statusCode: 404, statusMessage: 'Раздел не найден' })
}

useSeoMeta({
  title: () => `${section.value?.title || 'Форум'} — ${SITE_NAME}`,
  description: () => section.value?.description || `Форум ${SITE_NAME}`,
})

const feedUrl = computed(() => `/api/v1/feeds/forum/${section.value?.slug}.rss`)
const feedTitle = computed(() => `${SITE_NAME} — новые темы в разделе «${section.value?.title || ''}»`)

useHead(() => ({
  link: section.value
    ? [{ rel: 'alternate', type: 'application/rss+xml', title: feedTitle.value, href: feedUrl.value }]
    : [],
}))
</script>

<template>
  <div v-if="section" class="container">
    <div class="row mb-16 forum-breadcrumbs">
      <NuxtLink to="/forum" class="muted small">
        ← Форум
      </NuxtLink>
      <template v-if="section.parent">
        <span class="muted small">/</span>
        <NuxtLink :to="`/forum/${section.parent.slug}`" class="muted small">
          {{ section.parent.title }}
        </NuxtLink>
      </template>
    </div>

    <div class="page-head">
      <div>
        <h1>{{ section.title }}</h1>
        <p v-if="section.description">
          {{ section.description }}
        </p>
      </div>

      <div class="row">
        <RssLink :href="feedUrl" :title="feedTitle" />

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
    </div>

    <section v-if="children.length" class="section forum-subsections">
      <h2 class="section-title">
        Подразделы
      </h2>

      <div class="card forum-group-card">
        <ForumSectionRow
          v-for="child in children"
          :key="child.id"
          :section="child"
        />
      </div>
    </section>

    <div v-if="pending" class="empty">
      Загружаем темы…
    </div>

    <div v-else-if="!topics.length" class="empty">
      {{ children.length
        ? 'В этом разделе пока нет общих тем — выберите подраздел.'
        : 'Пока нет тем. Начните обсуждение первым.' }}
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
