<script setup lang="ts">
import type { Jam, JamEntryList } from '~/types/api'

const route = useRoute()
const api = useApi()
const { user } = useAuth()
const { plural } = useFormat()

const slug = computed(() => route.params.slug as string)
const page = computed(() => Math.max(1, Number(route.query.page) || 1))
const sort = computed(() => route.query.sort === 'oldest' ? 'oldest' : 'newest')
const userKey = computed(() => user.value?.id ?? 'guest')

const { data: jam, error: jamError } = await useAsyncData(
  () => `jam-entries-head-${slug.value}-${userKey.value}`,
  () => api.get<Jam>(`/api/v1/jams/${slug.value}`),
  { watch: [slug, userKey] },
)

const { data, pending, error } = await useAsyncData(
  () => `jam-entries-list-${slug.value}-${page.value}-${sort.value}-${userKey.value}`,
  () => api.get<JamEntryList>(`/api/v1/jams/${slug.value}/entries`, {
    page: page.value,
    sort: sort.value,
  }),
  { watch: [slug, page, sort, userKey] },
)

if (!jam.value && jamError.value) {
  throw createError({ statusCode: 404, statusMessage: 'Джем не найден' })
}

const entries = computed(() => data.value?.items ?? [])
const total = computed(() => data.value?.meta.total ?? 0)

useSeoMeta({
  title: () => `Заявки — ${jam.value?.title || 'джем'} — ${SITE_NAME}`,
})
</script>

<template>
  <div v-if="jam" class="container">
    <div class="row mb-16 forum-breadcrumbs">
      <NuxtLink to="/jams" class="muted small">← Джемы</NuxtLink>
      <span class="muted small">/</span>
      <NuxtLink :to="`/jams/${jam.slug}`" class="muted small">{{ jam.title }}</NuxtLink>
    </div>

    <div class="page-head">
      <div>
        <div class="row mb-8">
          <h1>Заявки</h1>
          <JamPhaseBadge :phase="jam.phase" />
        </div>
        <p class="muted small">
          {{ jam.title }} · {{ total }}
          {{ plural(total, 'заявка', 'заявки', 'заявок') }}
        </p>
      </div>

      <NuxtLink :to="`/jams/${jam.slug}`" class="btn btn-ghost">
        К джему
      </NuxtLink>
    </div>

    <div class="editor-tabs jam-tabs">
      <NuxtLink
        :to="`/jams/${jam.slug}/entries`"
        class="editor-tab"
        :class="{ active: sort === 'newest' }"
      >
        Новые
      </NuxtLink>
      <NuxtLink
        :to="`/jams/${jam.slug}/entries?sort=oldest`"
        class="editor-tab"
        :class="{ active: sort === 'oldest' }"
      >
        Старые
      </NuxtLink>
    </div>

    <div v-if="pending" class="empty">
      Загружаем заявки…
    </div>

    <div v-else-if="error" class="empty">
      Не удалось загрузить заявки.
    </div>

    <div v-else-if="!entries.length" class="empty">
      Заявок пока нет.
    </div>

    <template v-else>
      <div class="grid">
        <ProjectCard
          v-for="entry in entries"
          :key="entry.id"
          :project="entry.project"
        />
      </div>

      <ForumPagination
        :page="data?.meta.page || 1"
        :pages="data?.meta.pages || 1"
        :base-path="`/jams/${jam.slug}/entries`"
        :query="sort === 'oldest' ? { sort: 'oldest' } : {}"
      />
    </template>
  </div>
</template>
