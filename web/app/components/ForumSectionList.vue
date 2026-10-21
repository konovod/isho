<script setup lang="ts">
import type { ForumSection } from '~/types/api'

const props = defineProps<{
  sections: ForumSection[]
}>()

const { plural } = useFormat()

const groups = computed(() => {
  const map = new Map<string, ForumSection[]>()

  for (const section of props.sections) {
    const key = section.group_title || 'Разделы'
    const list = map.get(key) ?? []
    list.push(section)
    map.set(key, list)
  }

  return Array.from(map, ([title, items]) => ({ title, items }))
})
</script>

<template>
  <div class="forum-sections">
    <section v-for="group in groups" :key="group.title" class="forum-group">
      <h2 class="forum-group-title">{{ group.title }}</h2>

      <div class="card forum-group-card">
        <NuxtLink
          v-for="section in group.items"
          :key="section.id"
          :to="`/forum/${section.slug}`"
          class="forum-section-row"
        >
          <div class="forum-section-info">
            <h3>{{ section.title }}</h3>
            <p v-if="section.description" class="muted small">{{ section.description }}</p>
            <p class="muted small">
              {{ section.topics_count }}
              {{ plural(section.topics_count, 'тема', 'темы', 'тем') }}
              · {{ section.posts_count }}
              {{ plural(section.posts_count, 'сообщение', 'сообщения', 'сообщений') }}
            </p>
          </div>
          <span class="forum-section-arrow">→</span>
        </NuxtLink>
      </div>
    </section>
  </div>
</template>
