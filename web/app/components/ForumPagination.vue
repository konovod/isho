<script setup lang="ts">
const props = withDefaults(defineProps<{
  page: number
  pages: number
  basePath: string
  query?: Record<string, string>
}>(), {
  query: () => ({}),
})

const visiblePages = computed(() => {
  const total = props.pages
  const current = props.page
  const start = Math.max(1, Math.min(current - 2, total - 4))
  const end = Math.min(total, Math.max(current + 2, 5))

  return Array.from({ length: Math.max(0, end - start + 1) }, (_, index) => start + index)
})

function pageLink(page: number): string {
  const params = new URLSearchParams()

  for (const [key, value] of Object.entries(props.query)) {
    if (value) params.set(key, value)
  }

  if (page > 1) params.set('page', String(page))

  const query = params.toString()
  return query ? `${props.basePath}?${query}` : props.basePath
}
</script>

<template>
  <nav v-if="pages > 1" class="forum-pagination" aria-label="Страницы">
    <NuxtLink
      v-if="page > 1"
      :to="pageLink(page - 1)"
      class="forum-page-link forum-page-nav"
      aria-label="Предыдущая страница"
      title="Предыдущая страница"
    >
      ‹
    </NuxtLink>
    <span v-else class="forum-page-link forum-page-nav disabled" aria-hidden="true">‹</span>

    <div class="forum-pagination-pages">
      <NuxtLink
        v-for="number in visiblePages"
        :key="number"
        :to="pageLink(number)"
        class="forum-page-link"
        :class="{ active: number === page }"
      >
        {{ number }}
      </NuxtLink>
    </div>

    <NuxtLink
      v-if="page < pages"
      :to="pageLink(page + 1)"
      class="forum-page-link forum-page-nav"
      aria-label="Следующая страница"
      title="Следующая страница"
    >
      ›
    </NuxtLink>
    <span v-else class="forum-page-link forum-page-nav disabled" aria-hidden="true">›</span>
  </nav>
</template>
