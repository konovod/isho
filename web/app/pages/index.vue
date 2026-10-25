<script setup lang="ts">
import type { ProjectList, TagSummary } from '~/types/api'
import type { RouteLocationRaw } from 'vue-router'

const TAG_LIMIT = 20
const TAG_SEARCH_DEBOUNCE_MS = 250
const MAX_SELECTED_TAGS = 8

const FILTER_KINDS = [
  { value: 'game', label: 'Игры' },
  { value: 'tool', label: 'Инструменты' },
  { value: 'asset', label: 'Ассеты' },
] as const
type FilterKind = typeof FILTER_KINDS[number]['value']

const route = useRoute()
const router = useRouter()
const api = useApi()
const { user } = useAuth()
const { plural } = useFormat()

const feedUrl = '/api/v1/feeds/projects.rss'
const feedTitle = `${SITE_NAME} — новые проекты`

useHead({
  link: [
    { rel: 'alternate', type: 'application/rss+xml', title: feedTitle, href: feedUrl },
  ],
})

// The catalogue depends on the viewer's content preferences, so the cache must
// not be shared between a visitor and a signed-in account.
const viewerKey = computed(() => user.value?.id ?? 'guest')

const qInput = ref('')
const appliedQ = ref('')
const selectedTags = ref<string[]>([])
const kind = ref<FilterKind | ''>('')
const webOnly = ref(false)

// Query-only navigation reuses this component, so sync the filters from the URL.
watch(() => route.query, (query) => {
  appliedQ.value = typeof query.q === 'string' ? query.q : ''
  qInput.value = appliedQ.value

  const rawTags = query.tags
  const parts = (Array.isArray(rawTags) ? rawTags : rawTags ? [rawTags] : [])
    .flatMap(value => typeof value === 'string' ? value.split(',') : [])
    .map(value => value.trim())
    .filter(Boolean)
  // Project pages still link to the old single `?tag=` address.
  if (!parts.length && typeof query.tag === 'string' && query.tag.trim()) {
    parts.push(query.tag.trim())
  }
  selectedTags.value = [...new Set(parts)].slice(0, MAX_SELECTED_TAGS)

  const rawKind = typeof query.kind === 'string' ? query.kind : ''
  kind.value = FILTER_KINDS.some(item => item.value === rawKind) ? rawKind as FilterKind : ''
  webOnly.value = query.web === '1' || query.web === 'true'
}, { immediate: true })

// The tag strip is a facet of the catalogue: it asks the API which tags still
// have a project behind them, so a selected tag can only be paired with tags it
// actually occurs with.
const filtersActive = computed(() => selectedTags.value.length > 0 || !!kind.value || webOnly.value)
const anyFilterActive = computed(() => filtersActive.value || !!appliedQ.value)

const projectsKey = computed(() => [
  'projects',
  viewerKey.value,
  appliedQ.value,
  selectedTags.value.join(','),
  kind.value,
  webOnly.value ? 1 : 0,
].join(':'))

const { data, pending, error, refresh } = await useAsyncData(
  projectsKey,
  () => api.get<ProjectList>('/api/v1/projects', {
    q: appliedQ.value || undefined,
    tags: selectedTags.value.length ? selectedTags.value.join(',') : undefined,
    kind: kind.value || undefined,
    web: webOnly.value ? '1' : undefined,
  }),
)

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

const tagKey = computed(() => [
  'tags',
  viewerKey.value,
  appliedTagSearch.value,
  selectedTags.value.join(','),
  kind.value,
  webOnly.value ? 1 : 0,
].join(':'))

const { data: tagData, status: tagStatus } = await useAsyncData(
  tagKey,
  () => api.get<{ items: TagSummary[], meta: { total: number } }>('/api/v1/tags', {
    q: appliedTagSearch.value || undefined,
    limit: TAG_LIMIT,
    // A combination that still has a project must stay reachable, even when
    // it occurs once; the default threshold hides tags that group nothing.
    min_projects: filtersActive.value ? 1 : undefined,
    tags: selectedTags.value.length ? selectedTags.value.join(',') : undefined,
    kind: kind.value || undefined,
    web: webOnly.value ? '1' : undefined,
  }),
)

const tags = computed(() => tagData.value?.items ?? [])
const tagTotal = computed(() => tagData.value?.meta.total ?? 0)
const tagSearchActive = computed(() => appliedTagSearch.value.length > 0)

// The response drops to undefined while the next one is in flight, so remember
// the labels: a selected chip must keep its name while the list reloads.
const tagNames = ref<Record<string, string>>({})
watch(tags, (items) => {
  if (!items.length) return
  const next = { ...tagNames.value }
  for (const item of items) next[item.slug] = item.name
  tagNames.value = next
}, { immediate: true })

const selectedTagViews = computed(() => selectedTags.value.map(slug => ({
  slug,
  name: tagNames.value[slug] ?? slug,
  count: tags.value.find(item => item.slug === slug)?.projects_count,
})))

const otherTags = computed(() => tags.value.filter(item => !selectedTags.value.includes(item.slug)))

function writeQuery() {
  const query: Record<string, any> = { ...route.query }
  delete query.tag
  query.q = appliedQ.value || undefined
  query.tags = selectedTags.value.length ? selectedTags.value.join(',') : undefined
  query.kind = kind.value || undefined
  query.web = webOnly.value ? '1' : undefined
  router.replace({ query })
}

function toggleTag(slug: string) {
  selectedTags.value = selectedTags.value.includes(slug)
    ? selectedTags.value.filter(item => item !== slug)
    : [...selectedTags.value, slug].slice(0, MAX_SELECTED_TAGS)
  writeQuery()
}

function selectKind(value: FilterKind) {
  kind.value = kind.value === value ? '' : value
  writeQuery()
}

function toggleWebBuild() {
  webOnly.value = !webOnly.value
  writeQuery()
}

function submitSearch() {
  appliedQ.value = qInput.value.trim()
  writeQuery()
}

function resetFilters() {
  qInput.value = ''
  appliedQ.value = ''
  tagSearch.value = ''
  appliedTagSearch.value = ''
  selectedTags.value = []
  kind.value = ''
  webOnly.value = false

  const query: Record<string, any> = { ...route.query }
  for (const key of ['q', 'tags', 'tag', 'kind', 'web']) delete query[key]
  router.replace({ query })
}

// The link is the state the click would produce, so the tag can still be opened
// in a new tab while a plain click stays a filter toggle.
function tagTarget(slug: string): RouteLocationRaw {
  const next = selectedTags.value.includes(slug)
    ? selectedTags.value.filter(item => item !== slug)
    : [...selectedTags.value, slug].slice(0, MAX_SELECTED_TAGS)

  return {
    path: '/',
    query: {
      ...route.query,
      tag: undefined,
      tags: next.length ? next.join(',') : undefined,
    },
  }
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

        <RssLink class="mt-8" :href="feedUrl" :title="feedTitle" />

        <form class="search-row" @submit.prevent="submitSearch">
          <input
            v-model="qInput"
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
            <div class="tag-filter-title-row">
              <span class="tag-filter-title">Фильтры</span>
              <button
                type="button"
                class="tag-filter-reset"
                :class="{ 'is-hidden': !anyFilterActive }"
                @click="resetFilters"
              >
                Сбросить
              </button>
            </div>

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
              v-for="item in FILTER_KINDS"
              :key="item.value"
              type="button"
              class="tag tag-special tag-kind"
              :class="{ active: kind === item.value }"
              :aria-pressed="kind === item.value"
              @click="selectKind(item.value)"
            >
              {{ item.label }}
            </button>

            <button
              type="button"
              class="tag tag-special tag-web"
              :class="{ active: webOnly }"
              :aria-pressed="webOnly"
              @click="toggleWebBuild"
            >
              С веб-сборкой
            </button>

            <span class="tag-filter-sep" aria-hidden="true" />

            <TagPill
              v-for="item in selectedTagViews"
              :key="item.slug"
              :name="item.name"
              :to="tagTarget(item.slug)"
              :count="item.count"
              active
              @click.prevent="toggleTag(item.slug)"
            />

            <TagPill
              v-for="item in otherTags"
              :key="item.id"
              :name="item.name"
              :to="tagTarget(item.slug)"
              :count="item.projects_count"
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
          <template v-if="anyFilterActive">
            Ничего не нашлось. Попробуйте снять часть фильтров.
            <button class="btn btn-ghost btn-sm mt-16" type="button" @click="resetFilters">
              Сбросить фильтры
            </button>
          </template>
          <template v-else>
            Пока пусто. Стань первым, кто опубликует проект.
          </template>
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
