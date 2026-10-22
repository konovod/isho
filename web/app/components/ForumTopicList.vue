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

function displayName(user: { display_name: string | null, username: string }): string {
  return user.display_name || user.username
}
</script>

<template>
  <div class="forum-topic-list">
    <article
      v-for="topic in topics"
      :key="topic.id"
      class="card forum-topic-row"
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
        <span class="forum-topic-replies">
          {{ topic.replies_count }}
          {{ plural(topic.replies_count, 'ответ', 'ответа', 'ответов') }}
        </span>
        <span
          v-if="topic.replies_count > 0 && topic.last_post_author"
          class="forum-topic-last-author small"
          title="Последний ответ"
        >
          <NuxtLink :to="`/u/${topic.last_post_author.username}`">
            {{ displayName(topic.last_post_author) }}
          </NuxtLink>
        </span>
        <NuxtLink
          :to="lastPostPath(topic)"
          class="muted small"
          title="Перейти к последнему сообщению"
        >
          {{ dateTime(topic.last_post_at) }}
        </NuxtLink>
      </div>

      <NuxtLink
        :to="topicPath(topic)"
        class="forum-topic-open"
        aria-label="Открыть тему"
      >
        →
      </NuxtLink>
    </article>
  </div>
</template>
