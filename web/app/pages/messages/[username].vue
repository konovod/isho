<script setup lang="ts">
import type { PrivateMessage, PrivateMessageList } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'signed-in' })

const route = useRoute()
const api = useApi()
const { user, banned, impersonating, emailConfirmed } = useAuth()
const { setUnreadCount } = useMessages()

const username = computed(() => route.params.username as string)
const userKey = computed(() => user.value?.id ?? 'guest')

const { data, error } = await useAsyncData(
  () => `messages-chat-${username.value}-${userKey.value}`,
  () => api.get<PrivateMessageList>(`/api/v1/messages/${username.value}`),
  { watch: [username, userKey] },
)

if (!data.value && error.value) {
  throw createError({ statusCode: 404, statusMessage: 'Пользователь не найден' })
}

const peer = computed(() => data.value?.peer ?? null)
const messages = computed(() => data.value?.items ?? [])
const hasMore = computed(() => data.value?.has_more ?? false)

const peerName = computed(() => peer.value?.display_name || peer.value?.username || '')
const initials = computed(() => peerName.value.slice(0, 2))

const thread = ref<HTMLElement | null>(null)
const loadingOlder = ref(false)
const refreshing = ref(false)
const actionError = ref('')
// Loading older messages keeps the reader where they were, so the data
// watcher must not jump to the bottom for that one update.
let keepScroll = false

watch(data, (value) => {
  if (!value) return

  setUnreadCount(value.unread_count)
  if (!import.meta.client) return

  if (keepScroll) {
    keepScroll = false
    return
  }

  nextTick(() => scrollToBottom('auto'))
  markRead()
})

onMounted(() => {
  nextTick(() => scrollToBottom('auto'))
  markRead()
})

function scrollToBottom(behavior: ScrollBehavior = 'smooth') {
  nextTick(() => {
    const element = thread.value
    if (!element) return

    element.scrollTo({ top: element.scrollHeight, behavior })
  })
}

// Read markers are a write: the impersonation view must not change the target
// account's unread state. Banned accounts may still read and mark as read.
async function markRead() {
  if (!user.value || impersonating.value) return

  try {
    const result = await api.post<{ unread_count: number }>(`/api/v1/messages/${username.value}/read`)
    setUnreadCount(result.unread_count)
  }
  catch {
    // Failing to save a marker must not break reading the conversation.
  }
}

async function loadOlder() {
  const oldest = messages.value[0]
  if (!oldest || loadingOlder.value) return

  loadingOlder.value = true
  actionError.value = ''

  const element = thread.value
  const previousHeight = element?.scrollHeight ?? 0
  const previousTop = element?.scrollTop ?? 0

  try {
    const older = await api.get<PrivateMessageList>(`/api/v1/messages/${username.value}`, {
      before: oldest.id,
    })

    if (data.value) {
      keepScroll = true
      data.value = {
        ...data.value,
        items: [...older.items, ...data.value.items],
        has_more: older.has_more,
      }
    }

    setUnreadCount(older.unread_count)
    await nextTick()

    if (element) {
      element.scrollTop = element.scrollHeight - previousHeight + previousTop
    }
  }
  catch (err) {
    actionError.value = formatApiError(err, 'Не удалось загрузить ранние сообщения')
  }
  finally {
    loadingOlder.value = false
  }
}

async function refreshChat() {
  if (refreshing.value) return

  refreshing.value = true
  actionError.value = ''

  const newest = messages.value[messages.value.length - 1]

  try {
    const fresh = await api.get<PrivateMessageList>(
      `/api/v1/messages/${username.value}`,
      newest ? { after: newest.id } : undefined,
    )

    if (data.value) {
      const known = new Set(data.value.items.map(item => item.id))
      const items = newest
        ? [...data.value.items, ...fresh.items.filter(item => !known.has(item.id))]
        : fresh.items

      data.value = { ...data.value, items, unread_count: fresh.unread_count }
    }

    setUnreadCount(fresh.unread_count)
    scrollToBottom()
  }
  catch (err) {
    actionError.value = formatApiError(err, 'Не удалось обновить переписку')
  }
  finally {
    refreshing.value = false
  }
}

async function onPosted(message: PrivateMessage) {
  if (data.value) {
    data.value = { ...data.value, items: [...data.value.items, message] }
  }

  await nextTick()
  scrollToBottom()
}

useSeoMeta({
  title: () => `${peerName.value || 'Переписка'} — переписка — ${SITE_NAME}`,
  description: 'Личные сообщения видны только участникам переписки.',
  robots: 'noindex, nofollow',
})
</script>

<template>
  <div v-if="peer" class="container messages-page">
    <div class="messages-head">
      <NuxtLink to="/messages" class="muted small">← Переписка</NuxtLink>

      <div class="row-between chat-head">
        <div class="row">
          <span class="avatar">{{ initials }}</span>
          <div>
            <h1>{{ peerName }}</h1>
            <p class="muted small">
              <NuxtLink :to="`/u/${peer.username}`">@{{ peer.username }}</NuxtLink>
              · личные сообщения
            </p>
          </div>
        </div>

        <button class="btn btn-ghost btn-sm" type="button" :disabled="refreshing" @click="refreshChat">
          {{ refreshing ? 'Обновляем…' : 'Обновить' }}
        </button>
      </div>
    </div>

    <div v-if="actionError" class="form-error">
      {{ actionError }}
    </div>

    <div ref="thread" class="chat-thread">
      <div v-if="hasMore" class="chat-more">
        <button class="btn btn-ghost btn-sm" type="button" :disabled="loadingOlder" @click="loadOlder">
          {{ loadingOlder ? 'Загружаем…' : 'Показать более ранние' }}
        </button>
      </div>

      <div v-if="!messages.length" class="empty">
        Сообщений пока нет. Напишите первым.
      </div>

      <MessageBubble
        v-for="message in messages"
        :key="message.id"
        :message="message"
      />
    </div>

    <MessageComposer
      v-if="user && !banned && !impersonating && emailConfirmed"
      :username="peer.username"
      class="mt-24"
      @posted="onPosted"
    />

    <div v-else-if="banned" class="empty mt-24">
      Аккаунт забанен — писать нельзя до окончания срока.
    </div>

    <div v-else-if="impersonating" class="empty mt-24">
      Режим просмотра: отправка сообщений недоступна.
    </div>

    <div v-else-if="user && !emailConfirmed" class="empty mt-24">
      Подтвердите почту, чтобы отвечать.
      <NuxtLink to="/settings">Настройки</NuxtLink>
    </div>
  </div>
</template>
