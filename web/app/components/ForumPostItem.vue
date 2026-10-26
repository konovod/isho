<script setup lang="ts">
import type { ApiUser, ForumPost, ForumPostReactions, ForumReactionKind, ForumReactionVoters } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = defineProps<{
  post: ForumPost
  currentUserId?: number
  canModerate: boolean
  isFirst?: boolean
  unread?: boolean
}>()

const emit = defineEmits<{
  quote: [post: ForumPost, text: string]
  deleted: [post: ForumPost]
  updated: [post: ForumPost]
}>()

const api = useApi()
const route = useRoute()
const { dateTime } = useFormat()

const bodyEl = ref<HTMLElement | null>(null)
const editing = ref(false)
const draft = ref('')
const saving = ref(false)
const localError = ref('')
// Set on pointerdown, because the browser drops the selection before `click`.
let pendingQuote = ''

const reactionKinds: ForumReactionKind[] = ['like', 'dislike']
const reactions = ref<ForumPostReactions>({ ...props.post.reactions })
const voting = ref<ForumReactionKind | null>(null)
const reactionError = ref('')

interface VoterPopup extends ForumReactionVoters {
  loading: boolean
  error: string
}

const voters = ref<VoterPopup | null>(null)
const reactionsEl = ref<HTMLElement | null>(null)

watch(() => props.post.reactions, (value) => {
  reactions.value = { ...value }
}, { deep: true })

const isOwnPost = computed(() => !!props.currentUserId && props.post.author.id === props.currentUserId)

function countFor(kind: ForumReactionKind): number {
  return kind === 'like' ? reactions.value.likes_count : reactions.value.dislikes_count
}

function voterName(voter: ApiUser): string {
  return voter.display_name || voter.username
}

// The server rejects a vote on the own message; the UI keeps the symbols
// visible but inert, so the counters and the popup still work there.
function voteTitle(kind: ForumReactionKind): string {
  if (isOwnPost.value) return 'Нельзя голосовать за своё сообщение'
  if (!props.currentUserId) return 'Войдите, чтобы голосовать'
  return kind === 'like' ? 'Нравится' : 'Не нравится'
}

function withReaction(state: ForumPostReactions, next: ForumReactionKind | null): ForumPostReactions {
  const likes = state.likes_count - (state.my_reaction === 'like' ? 1 : 0) + (next === 'like' ? 1 : 0)
  const dislikes = state.dislikes_count - (state.my_reaction === 'dislike' ? 1 : 0) + (next === 'dislike' ? 1 : 0)

  return {
    likes_count: Math.max(0, likes),
    dislikes_count: Math.max(0, dislikes),
    my_reaction: next,
  }
}

async function vote(kind: ForumReactionKind) {
  if (isOwnPost.value || voting.value) return

  if (!props.currentUserId) {
    await navigateTo('/sign_in')
    return
  }

  const previous = { ...reactions.value }
  const next = previous.my_reaction === kind ? null : kind
  reactions.value = withReaction(previous, next)
  voting.value = kind
  reactionError.value = ''

  try {
    const result = await api.post<{ reactions: ForumPostReactions }>(
      `/api/v1/forum/posts/${props.post.id}/reactions`,
      { forum_post_reaction: { kind } },
    )
    reactions.value = { ...result.reactions }

    // The visible list is stale after the reader's own vote.
    if (voters.value) await loadVoters(voters.value.kind, true)
  }
  catch (err) {
    reactions.value = previous
    reactionError.value = formatApiError(err)
  }
  finally {
    voting.value = null
  }
}

async function toggleVoters(kind: ForumReactionKind) {
  if (voters.value?.kind === kind) {
    voters.value = null
    return
  }

  await loadVoters(kind)
}

async function loadVoters(kind: ForumReactionKind, silent = false) {
  if (!silent || voters.value?.kind !== kind) {
    voters.value = {
      kind,
      total: countFor(kind),
      items: [],
      truncated: false,
      loading: true,
      error: '',
    }
  }

  try {
    const result = await api.get<ForumReactionVoters>(
      `/api/v1/forum/posts/${props.post.id}/reactions?kind=${kind}`,
    )
    if (voters.value?.kind !== kind) return
    voters.value = { ...result, loading: false, error: '' }
  }
  catch (err) {
    if (voters.value?.kind !== kind) return
    voters.value = { ...voters.value, loading: false, error: formatApiError(err) }
  }
}

function closeVoters() {
  voters.value = null
}

function onDocumentPointerDown(event: PointerEvent) {
  if (!voters.value) return
  const target = event.target as Node | null
  if (target && reactionsEl.value?.contains(target)) return
  closeVoters()
}

function onDocumentKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') closeVoters()
}

onMounted(() => {
  document.addEventListener('pointerdown', onDocumentPointerDown)
  document.addEventListener('keydown', onDocumentKeydown)
})

onUnmounted(() => {
  document.removeEventListener('pointerdown', onDocumentPointerDown)
  document.removeEventListener('keydown', onDocumentKeydown)
})

const authorName = computed(() => props.post.author.display_name || props.post.author.username)
const initials = computed(() => authorName.value.slice(0, 2))
const canEdit = computed(() => !!props.currentUserId && (props.post.author.id === props.currentUserId || props.canModerate))

const quoteAuthorName = computed(() => {
  const quote = props.post.quote
  return quote?.author_name || quote?.author_username || 'Цитата'
})

const quoteHref = computed(() => {
  const quote = props.post.quote
  if (!quote?.post_id) return null

  const currentPage = Number(route.query.page) || 1
  const page = quote.page && quote.page !== currentPage ? `?page=${quote.page}` : ''

  return `${route.path}${page}#post-${quote.post_id}`
})

function selectedInBody(): string {
  const selection = window.getSelection()
  const body = bodyEl.value

  if (!selection || selection.isCollapsed || selection.rangeCount === 0 || !body) return ''

  const range = selection.getRangeAt(0)
  if (!body.contains(range.commonAncestorContainer)) return ''

  return selection.toString().trim().slice(0, FORUM_QUOTE_MAX_CHARS)
}

function rememberSelection() {
  pendingQuote = selectedInBody()
}

function quoteFromClick() {
  const text = pendingQuote || selectedInBody()
  pendingQuote = ''
  emit('quote', props.post, text)
}

function startEdit() {
  draft.value = props.post.body
  localError.value = ''
  editing.value = true
}

function cancelEdit() {
  editing.value = false
  localError.value = ''
}

async function save() {
  if (!draft.value.trim()) {
    localError.value = 'Добавьте текст сообщения.'
    return
  }

  saving.value = true
  localError.value = ''

  try {
    const updated = await api.patch<ForumPost>(`/api/v1/forum/posts/${props.post.id}`, {
      forum_post: { body: draft.value.trim() },
    })

    emit('updated', updated)
    editing.value = false
  }
  catch (err) {
    localError.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <article
    :id="`post-${post.id}`"
    class="forum-post"
    :class="{ 'is-unread': unread }"
  >
    <header class="forum-post-head">
      <div class="forum-post-who">
        <span class="avatar">{{ initials }}</span>
        <div class="forum-post-who-text">
          <NuxtLink :to="`/u/${post.author.username}`" class="forum-post-author-name">
            {{ authorName }}
          </NuxtLink>
          <span class="forum-post-user">@{{ post.author.username }}</span>
          <span
            v-if="post.author.ai_flair"
            class="forum-flair"
            title="Сгенерировано ИИ из последних сообщений автора"
          >
            <span aria-hidden="true">✦</span> {{ post.author.ai_flair }}
          </span>
        </div>
      </div>

      <div class="forum-post-side">
        <div class="forum-post-actions">
          <div ref="reactionsEl" class="forum-reactions">
            <div
              v-for="kind in reactionKinds"
              :key="kind"
              class="forum-reaction"
              :class="[kind, { 'is-active': reactions.my_reaction === kind }]"
            >
              <button
                type="button"
                class="forum-reaction-vote"
                :disabled="isOwnPost"
                :aria-label="kind === 'like' ? 'Нравится' : 'Не нравится'"
                :aria-pressed="reactions.my_reaction === kind"
                :title="voteTitle(kind)"
                @click="vote(kind)"
              >
                <svg
                  v-if="kind === 'like'"
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78z" />
                </svg>
                <svg
                  v-else
                  viewBox="0 0 24 24"
                  aria-hidden="true"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path d="M17 14V2" />
                  <path d="M9 18.12 10 14H4.17a2 2 0 0 1-1.92-2.56l2.33-8A2 2 0 0 1 6.5 2H20a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.76a2 2 0 0 0-1.79 1.11L12 22a3.13 3.13 0 0 1-3-3.88Z" />
                </svg>
              </button>

              <button
                type="button"
                class="forum-reaction-count"
                aria-haspopup="dialog"
                :aria-expanded="voters?.kind === kind"
                :aria-label="`Кто проголосовал: ${kind === 'like' ? 'нравится' : 'не нравится'}`"
                @click="toggleVoters(kind)"
              >
                {{ countFor(kind) }}
              </button>

              <div
                v-if="voters?.kind === kind"
                class="forum-reaction-popup"
                role="dialog"
                :aria-label="kind === 'like' ? 'Кому нравится' : 'Кому не нравится'"
              >
                <p v-if="voters.loading" class="muted small">
                  Загружаем…
                </p>
                <p v-else-if="voters.error" class="form-error small">
                  {{ voters.error }}
                </p>
                <template v-else-if="!voters.items.length">
                  <p class="muted small">
                    Пока никто не голосовал.
                  </p>
                </template>
                <template v-else>
                  <NuxtLink
                    v-for="voter in voters.items"
                    :key="voter.id"
                    :to="`/u/${voter.username}`"
                    class="forum-reaction-voter"
                  >
                    {{ voterName(voter) }}
                    <span class="muted">@{{ voter.username }}</span>
                  </NuxtLink>
                  <p v-if="voters.truncated" class="forum-reaction-more muted small">
                    … и ещё {{ voters.total - voters.items.length }}
                  </p>
                </template>
              </div>
            </div>
          </div>

          <button
            v-if="currentUserId"
            type="button"
            class="btn btn-ghost btn-sm"
            @pointerdown="rememberSelection"
            @click="quoteFromClick"
          >
            Цитировать
          </button>
          <button
            v-if="canEdit && !editing"
            type="button"
            class="btn btn-ghost btn-sm"
            @click="startEdit"
          >
            Изменить
          </button>
          <button
            v-if="canModerate && !isFirst"
            type="button"
            class="btn btn-danger btn-sm"
            @click="emit('deleted', post)"
          >
            Удалить
          </button>
        </div>

        <span class="forum-post-date">
          {{ dateTime(post.created_at) }}
          <template v-if="post.edited"> · изменено</template>
          <span v-if="unread" class="forum-post-new">новое</span>
        </span>
      </div>
    </header>

    <div class="forum-post-main">
      <div v-if="post.quote" class="forum-quote">
        <div class="forum-quote-author">
          <NuxtLink
            v-if="quoteHref"
            :to="quoteHref"
            title="Перейти к сообщению"
          >
            {{ quoteAuthorName }}<span class="forum-quote-arrow" aria-hidden="true">↗</span>
          </NuxtLink>
          <template v-else>
            {{ quoteAuthorName }}
          </template>
        </div>
        <MarkdownBody :source="post.quote.body" />
      </div>

      <template v-if="!editing">
        <div
          ref="bodyEl"
          class="forum-post-body"
          data-quote-body
          :data-post-id="post.id"
        >
          <MarkdownBody :source="post.body" />
        </div>
      </template>

      <template v-else>
        <div v-if="localError" class="form-error">
          {{ localError }}
        </div>

        <MarkdownEditor
          :id="`post-${post.id}-body`"
          v-model="draft"
          :rows="8"
          :maxlength="20000"
          placeholder="Текст сообщения"
        />

        <div class="row mt-16">
          <button class="btn btn-primary btn-sm" :disabled="saving" @click="save">
            {{ saving ? 'Сохраняем…' : 'Сохранить' }}
          </button>
          <button class="btn btn-ghost btn-sm" :disabled="saving" @click="cancelEdit">
            Отмена
          </button>
        </div>
      </template>

      <p v-if="reactionError" class="forum-reaction-error">
        {{ reactionError }}
      </p>
    </div>
  </article>
</template>
