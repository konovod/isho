<script setup lang="ts">
import type { ForumTopic } from '~/types/api'

withDefaults(defineProps<{
  topics: ForumTopic[]
  showProject?: boolean
}>(), {
  showProject: true,
})

const { dateTime, plural } = useFormat()
</script>

<template>
  <div class="forum-topic-list">
    <article v-for="topic in topics" :key="topic.id" class="card forum-topic-row">
      <div class="forum-topic-main">
        <NuxtLink :to="`/forum/${topic.section.slug}/${topic.slug}`" class="forum-topic-title">
          {{ topic.title }}
        </NuxtLink>

        <div class="forum-topic-meta muted small">
          <NuxtLink :to="`/u/${topic.author.username}`">
            {{ topic.author.display_name || topic.author.username }}
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
        <span class="muted small">{{ dateTime(topic.last_post_at) }}</span>
      </div>

      <NuxtLink
        :to="`/forum/${topic.section.slug}/${topic.slug}`"
        class="forum-topic-open"
        aria-label="Открыть тему"
      >
        →
      </NuxtLink>
    </article>
  </div>
</template>
