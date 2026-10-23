<script setup lang="ts">
import type { ProjectList, TagSummary } from '~/types/api'

const TAG_LIMIT = 20
const TAG_SEARCH_DEBOUNCE_MS = 250

const route = useRoute()
const router = useRouter()
const api = useApi()
const { user } = useAuth()
const { plural } = useFormat()

// The catalogue depends on the viewer's content preferences, so the cache must
// not be shared between a visitor and a signed-in account.
const viewerKey = computed(() => user.value?.id ?? 'guest')

const q = ref('')
const tag = ref('')

// Query-only navigation reuses this component, so sync the filters from the URL.
watch(() => route.query, (query) => {
  q.value = typeof query.q === 'string' ? query.q : ''
  tag.value = typeof query.tag === 'string' ? query.tag : ''
}, { immediate: true })

// There can be hundreds of tags, so the strip renders only the popular ones.
// The search field queries the API, so it finds tags outside that list too.
const tagSearch = ref('')
const appliedTagSearch = ref('')
let tagSearchTimer: ReturnType<typeof setTimeout> | undefined

watch(tagSearch, (value) => {
  clearTimeout(tagSearchTimer)
  tagSearchTimer = setTimeout(() => {
    appliedTagSearch.value = value.trim()
  }, TAG_SEARCH_DEBOUNCE_MS)
})

onBeforeUnmount(() => clearTimeout(tagSearchTimer))

const { data: tagData, status: tagStatus } = await useAsyncData(
  () => `tags:${viewerKey.value}`,
  () => api.get<{ items: TagSummary[], meta: { total: number } }>('/api/v1/tags', {
    q: appliedTagSearch.value || undefined,
    limit: TAG_LIMIT,
  }),
  { watch: [appliedTagSearch] },
)

const tags = computed(() => tagData.value?.items ?? [])
const tagTotal = computed(() => tagData.value?.meta.total ?? 0)
const tagSearchActive = computed(() => appliedTagSearch.value.length > 0)
const activeTagVisible = computed(() => tags.value.some(item => item.slug === tag.value))

const projectsKey = computed(() => `projects:${viewerKey.value}:${q.value.trim()}:${tag.value}`)
const { data, pending, error, refresh } = await useAsyncData(
  projectsKey,
  () => api.get<ProjectList>('/api/v1/projects', {
    q: q.value.trim() || undefined,
    tag: tag.value || undefined,
  }),
  { watch: [q, tag] },
)

function toggleTag(slug: string) {
  tag.value = tag.value === slug ? '' : slug
  router.replace({ query: { ...route.query, tag: tag.value || undefined } })
}

function clearTag() {
  tag.value = ''
  router.replace({ query: { ...route.query, tag: undefined } })
}

function submitSearch() {
  router.replace({ query: { ...route.query, q: q.value.trim() || undefined } })
}
</script>

<template>
  <div>
    <section class="hero">
      <div class="container">
        <h1>Игры, которые делают люди</h1>
        <p>
          Небольшие проекты, эксперименты и большие идеи. Найди что-то новое
          или покажи своё.
        </p>

        <form class="search-row" @submit.prevent="submitSearch">
          <input
            v-model="q"
            class="input"
            type="search"
            placeholder="Поиск по названию…"
            aria-label="Поиск проектов"
          >
          <button class="btn btn-primary" type="submit">
            Найти
          </button>
        </form>
      </div>
    </section>

    <section class="section">
      <div class="container">
        <div class="tag-filter mb-16">
          <div class="tag-filter-head">
            <span class="tag-filter-title">Популярные теги</span>

            <input
              v-model="tagSearch"
              class="input tag-filter-input"
              type="search"
              placeholder="Поиск тега…"
              aria-label="Поиск тегов"
            >

            <span class="muted small tag-filter-count">
              {{ data?.meta.total ?? 0 }} {{ plural(data?.meta.total ?? 0, 'проект', 'проекта', 'проектов') }}
            </span>
          </div>

          <div class="row tag-filter-list" aria-live="polite">
            <button
              v-if="tag && !activeTagVisible"
              type="button"
              class="tag tag-reset"
              @click="clearTag"
            >
              Сбросить тег
            </button>

            <TagPill
              v-for="item in tags"
              :key="item.id"
              :tag="item"
              :count="item.projects_count"
              :active="tag === item.slug"
              @click.prevent="toggleTag(item.slug)"
            />

            <span v-if="!tags.length && tagStatus !== 'pending'" class="muted small">
              {{ tagSearchActive ? 'Тегов по запросу не нашлось.' : 'Пока нет тегов.' }}
            </span>
          </div>

          <p v-if="tagSearchActive && tagTotal > tags.length" class="hint tag-filter-hint">
            Найдено {{ tagTotal }} — показаны первые {{ tags.length }}. Уточните запрос.
          </p>
        </div>

        <div v-if="pending" class="empty">
          Загружаем проекты…
        </div>

        <div v-else-if="error" class="empty">
          Не удалось загрузить каталог.
          <button class="btn btn-ghost btn-sm mt-16" @click="refresh()">
            Повторить
          </button>
        </div>

        <div v-else-if="!data?.items.length" class="empty">
          Пока пусто. Стань первым, кто опубликует проект.
        </div>

        <div v-else class="grid">
          <ProjectCard
            v-for="project in data.items"
            :key="project.id"
            :project="project"
          />
        </div>
      </div>
    </section>
  </div>
</template>
