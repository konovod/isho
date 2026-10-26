<script setup lang="ts">
import type { PrivateMessage } from '~/types/api'

const props = defineProps<{ message: PrivateMessage }>()

const { dateTime } = useFormat()

const authorName = computed(() => {
  const author = props.message.author
  return author.display_name || author.username
})
</script>

<template>
  <article class="chat-message" :class="{ 'is-mine': message.mine }">
    <span class="avatar chat-avatar">{{ authorName.slice(0, 2) }}</span>

    <div class="chat-bubble">
      <div class="chat-meta">
        <span v-if="message.mine" class="chat-author">Вы</span>
        <NuxtLink v-else :to="`/u/${message.author.username}`" class="chat-author">
          {{ authorName }}
        </NuxtLink>
        <span>· {{ dateTime(message.created_at) }}</span>
      </div>

      <MarkdownBody :source="message.body" />
    </div>
  </article>
</template>
