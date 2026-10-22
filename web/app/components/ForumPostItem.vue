<script setup lang="ts">
import type { ForumPost } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = defineProps<{
  post: ForumPost
  currentUserId?: number
  canModerate: boolean
  isFirst?: boolean
  unread?: boolean
}>()

const emit = defineEmits<{
  quote: [post: ForumPost]
  deleted: [post: ForumPost]
  updated: [post: ForumPost]
}>()

const api = useApi()
const { dateTime } = useFormat()

const editing = ref(false)
const draft = ref('')
const saving = ref(false)
const localError = ref('')

const authorName = computed(() => props.post.author.display_name || props.post.author.username)
const initials = computed(() => authorName.value.slice(0, 2))
const canEdit = computed(() => !!props.currentUserId && (props.post.author.id === props.currentUserId || props.canModerate))

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
    <aside class="forum-post-author">
      <span class="avatar">{{ initials }}</span>
      <NuxtLink :to="`/u/${post.author.username}`" class="forum-post-author-name">
        {{ authorName }}
      </NuxtLink>
      <span class="muted small">@{{ post.author.username }}</span>
    </aside>

    <div class="forum-post-main">
      <header class="forum-post-head">
        <span class="muted small">
          {{ dateTime(post.created_at) }}
          <template v-if="post.edited"> · изменено</template>
          <span v-if="unread" class="forum-post-new">новое</span>
        </span>

        <div class="forum-post-actions">
          <button
            v-if="currentUserId"
            type="button"
            class="btn btn-ghost btn-sm"
            @click="emit('quote', post)"
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
      </header>

      <div v-if="post.quote" class="forum-quote">
        <div class="forum-quote-author">
          {{ post.quote.author_name || post.quote.author_username || 'Цитата' }}
        </div>
        <MarkdownBody :source="post.quote.body" />
      </div>

      <template v-if="!editing">
        <MarkdownBody :source="post.body" />
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
    </div>
  </article>
</template>
