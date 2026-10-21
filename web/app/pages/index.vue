<script setup lang="ts">
import type { ProjectList, Tag } from '~/types/api'

const route = useRoute()
const router = useRouter()
const api = useApi()
const { plural } = useFormat()

const q = ref('')
const tag = ref('')

// Query-only navigation reuses this component, so sync the filters from the URL.
watch(() => route.query, (query) => {
  q.value = typeof query.q === 'string' ? query.q : ''
  tag.value = typeof query.tag === 'string' ? query.tag : ''
}, { immediate: true })

const { data: tagData } = await useAsyncData('tags', () => api.get<{ items: Tag[] }>('/api/v1/tags'))
const projectsKey = computed(() => `projects:${q.value.trim()}:${tag.value}`)
const { data, pending, error, refresh } = await useAsyncData(
  projectsKey,
  () => api.get<ProjectList>('/api/v1/projects', {
    q: q.value.trim() || undefined,
    tag: tag.value || undefined,
  }),
  { watch: [q, tag] },
)

const tags = computed(() => tagData.value?.items ?? [])

function toggleTag(slug: string) {
  tag.value = tag.value === slug ? '' : slug
  router.replace({ query: { ...route.query, tag: tag.value || undefined } })
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
        <div class="row-between mb-16">
          <div class="row">
            <TagPill
              v-for="item in tags"
              :key="item.id"
              :tag="item"
              :active="tag === item.slug"
              @click.prevent="toggleTag(item.slug)"
            />
          </div>

          <span class="muted small">
            {{ data?.meta.total ?? 0 }} {{ plural(data?.meta.total ?? 0, 'проект', 'проекта', 'проектов') }}
          </span>
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
