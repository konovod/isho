<script setup lang="ts">
import type { ApiUser, ConversationList } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'signed-in' })

const api = useApi()
const { user } = useAuth()
const { setUnreadCount } = useMessages()
const { dateTime } = useFormat()

const { data, pending, error, refresh } = await useAsyncData(
  () => `messages-inbox-${user.value?.id ?? 'guest'}`,
  () => api.get<ConversationList>('/api/v1/messages'),
)

watch(data, (value) => {
  if (value) setUnreadCount(value.unread_count)
}, { immediate: true })

const conversations = computed(() => data.value?.items ?? [])
const refreshing = ref(false)
const actionError = ref('')

async function refreshInbox() {
  refreshing.value = true
  actionError.value = ''

  try {
    await refresh()
  }
  catch (err) {
    actionError.value = formatApiError(err, 'Не удалось обновить переписку')
  }
  finally {
    refreshing.value = false
  }
}

function initials(name: string): string {
  return name.slice(0, 2)
}

function peerName(peer: ApiUser): string {
  return peer.display_name || peer.username
}

function preview(body: string): string {
  const text = markdownToText(body).replace(/\s+/g, ' ').trim()
  return text.length > 120 ? `${text.slice(0, 120)}…` : text
}

useSeoMeta({
  title: `Переписка — ${SITE_NAME}`,
  description: 'Личные сообщения на И.ШО.',
  robots: 'noindex, nofollow',
})
</script>

<template>
  <div class="container messages-page">
    <div class="page-head">
      <div>
        <h1>Переписка</h1>
        <p>Личные сообщения видны только вам и собеседнику.</p>
      </div>

      <button class="btn btn-ghost btn-sm" type="button" :disabled="refreshing" @click="refreshInbox">
        {{ refreshing ? 'Обновляем…' : 'Обновить' }}
      </button>
    </div>

    <div v-if="actionError" class="form-error">
      {{ actionError }}
    </div>

    <div v-if="error" class="empty">
      Не удалось загрузить переписку.
    </div>

    <div v-else-if="pending && !data" class="empty">
      Загружаем переписку…
    </div>

    <div v-else-if="!conversations.length" class="empty">
      Переписок пока нет. Откройте профиль автора и нажмите «Переписка».
    </div>

    <ul v-else class="conversation-list">
      <li v-for="conversation in conversations" :key="conversation.peer.id">
        <NuxtLink
          :to="`/messages/${conversation.peer.username}`"
          class="conversation-row"
          :class="{ 'is-unread': conversation.unread_count > 0 }"
        >
          <span class="avatar">{{ initials(peerName(conversation.peer)) }}</span>

          <span class="conversation-main">
            <span class="conversation-head">
              <span class="conversation-name">{{ peerName(conversation.peer) }}</span>
              <span class="conversation-time">{{ dateTime(conversation.last_message.created_at) }}</span>
            </span>
            <span class="conversation-preview">
              <span v-if="conversation.last_message.mine" class="muted">Вы: </span>{{ preview(conversation.last_message.body) }}
            </span>
          </span>

          <span v-if="conversation.unread_count" class="conversation-badge">
            {{ conversation.unread_count > 99 ? '99+' : conversation.unread_count }}
          </span>
        </NuxtLink>
      </li>
    </ul>
  </div>
</template>
