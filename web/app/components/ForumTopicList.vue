<script setup lang="ts">
import type { ForumTopic } from '~/types/api'

withDefaults(defineProps<{
  topics: ForumTopic[]
  showProject?: boolean
}>(), {
  showProject: true,
})

const { dateTime, plural } = useFormat()

function topicPath(topic: ForumTopic): string {
  const base = `/forum/${topic.section.slug}/${topic.slug}`
  if (topic.unread_count <= 0) return base

  const page = topic.first_unread_page > 1 ? `?page=${topic.first_unread_page}` : ''
  return `${base}${page}#unread`
}

function lastPostPath(topic: ForumTopic): string {
  const base = `/forum/${topic.section.slug}/${topic.slug}`
  const page = topic.last_page > 1 ? `?page=${topic.last_page}` : ''
  return `${base}${page}#last`
}

function repliesLabel(topic: ForumTopic): string {
  return `${topic.replies_count} ${plural(topic.replies_count, 'ответ', 'ответа', 'ответов')}`
}

function displayName(user: { display_name: string | null, username: string }): string {
  return user.display_name || user.username
}
</script>

<template>
  <div class="forum-topic-list">
    <article
      v-for="topic in topics"
      :key="topic.id"
      class="forum-topic-row"
      :class="{ 'is-unread': topic.unread_count > 0 }"
    >
      <div class="forum-topic-main">
        <NuxtLink :to="topicPath(topic)" class="forum-topic-title">
          {{ topic.title }}
        </NuxtLink>
        <span
          v-if="topic.unread_count > 0"
          class="forum-unread-badge"
          :title="`Непрочитанных сообщений: ${topic.unread_count}`"
          :aria-label="`Непрочитанных сообщений: ${topic.unread_count}`"
        >
          {{ topic.unread_count }}
        </span>

        <div class="forum-topic-meta muted small">
          <NuxtLink :to="`/u/${topic.author.username}`">
            {{ displayName(topic.author) }}
          </NuxtLink>
          <span>·</span>
          <span>{{ dateTime(topic.created_at) }}</span>
          <template v-if="showProject && topic.project">
            <span>·</span>
            <NuxtLink :to="`/p/${topic.project.slug}`" class="forum-project-link">
              {{ topic.project.title }}
            </NuxtLink>
          </template>
        </div>
      </div>

      <div class="forum-topic-stats">
        <span
          v-if="topic.replies_count > 0 && topic.last_post_author"
          class="forum-topic-last-author"
          title="Последний ответ"
        >
          <NuxtLink :to="`/u/${topic.last_post_author.username}`">
            {{ displayName(topic.last_post_author) }}
          </NuxtLink>
        </span>
        <NuxtLink
          :to="lastPostPath(topic)"
          class="forum-topic-last-date"
          title="Перейти к последнему сообщению"
        >
          {{ dateTime(topic.last_post_at) }}
        </NuxtLink>
        <NuxtLink
          :to="topicPath(topic)"
          class="forum-topic-replies"
          :title="repliesLabel(topic)"
          :aria-label="repliesLabel(topic)"
        >
          {{ topic.replies_count }}
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.6 8.6 0 0 1-3.7-.9L3 21l2-4.9a8.4 8.4 0 0 1-1-4A8.4 8.4 0 0 1 12.5 3 8.4 8.4 0 0 1 21 11.5z" />
          </svg>
        </NuxtLink>
      </div>
    </article>
  </div>
</template>
