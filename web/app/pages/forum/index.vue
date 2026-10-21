<script setup lang="ts">
import type { ForumSection } from '~/types/api'

const api = useApi()

const { data, error } = await useAsyncData(
  'forum-sections',
  () => api.get<{ items: ForumSection[] }>('/api/v1/forum/sections'),
)

const sections = computed(() => data.value?.items ?? [])

useSeoMeta({
  title: `Форум — ${SITE_NAME}`,
  description: `Форум ${SITE_NAME}: обсуждения разработки игр, проектов и инструментов.`,
})
</script>

<template>
  <div class="container">
    <div class="page-head">
      <div>
        <h1>Форум</h1>
        <p>Обсуждайте разработку, задавайте вопросы и рассказывайте о проектах.</p>
      </div>
    </div>

    <div v-if="error" class="empty">
      Не удалось загрузить форум.
    </div>

    <div v-else-if="!sections.length" class="empty">
      Разделы форума ещё не настроены.
    </div>

    <ForumSectionList v-else :sections="sections" />
  </div>
</template>
