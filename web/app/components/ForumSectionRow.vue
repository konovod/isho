<script setup lang="ts">
import type { ForumSection } from '~/types/api'

const props = defineProps<{
  section: ForumSection
  child?: boolean
}>()

const { plural } = useFormat()

const counts = computed(() => {
  const section = props.section
  const topics = `${section.topics_count} ${plural(section.topics_count, 'тема', 'темы', 'тем')}`
  const posts = `${section.posts_count} ${plural(section.posts_count, 'сообщение', 'сообщения', 'сообщений')}`

  if (section.children_count > 0) {
    const subsections = `${section.children_count} ${plural(section.children_count, 'подраздел', 'подраздела', 'подразделов')}`
    return `${subsections} · ${topics} · ${posts}`
  }

  return `${topics} · ${posts}`
})
</script>

<template>
  <NuxtLink
    :to="`/forum/${section.slug}`"
    class="forum-section-row"
    :class="{ 'forum-section-child-row': child }"
  >
    <div class="forum-section-info">
      <h3>
        <span v-if="child" class="forum-section-child-mark" aria-hidden="true">↳</span>
        {{ section.title }}
        <span
          v-if="section.unread_topics_count > 0"
          class="forum-unread-badge"
          :title="`Непрочитанных тем: ${section.unread_topics_count}`"
          :aria-label="`Непрочитанных тем: ${section.unread_topics_count}`"
        >
          {{ section.unread_topics_count }}
        </span>
      </h3>
      <p v-if="section.description" class="forum-section-desc">{{ section.description }}</p>
    </div>
    <span class="forum-section-counts">{{ counts }}</span>
  </NuxtLink>
</template>
