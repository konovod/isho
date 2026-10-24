<script setup lang="ts">
import type { ForumPost, ForumQuoteDraft } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = defineProps<{
  topicId: number
  quote: ForumQuoteDraft | null
}>()

const emit = defineEmits<{
  posted: [post: ForumPost]
  'cancel-quote': []
}>()

const api = useApi()
const container = ref<HTMLElement | null>(null)
const body = ref('')
const saving = ref(false)
const error = ref('')

const quotePreview = computed(() => {
  const quote = props.quote
  if (!quote) return ''

  const source = quote.text || markdownToText(quote.post.body)
  const text = source.replace(/\s+/g, ' ').trim()

  return text.length > 220 ? `${text.slice(0, 220)}…` : text
})

const quoteAuthor = computed(() => {
  const post = props.quote?.post
  if (!post) return ''
  return post.author.display_name || post.author.username
})

function focus() {
  nextTick(() => {
    container.value?.scrollIntoView({ behavior: 'smooth', block: 'center' })
    container.value?.querySelector<HTMLTextAreaElement>('textarea')?.focus()
  })
}

async function submit() {
  if (!body.value.trim()) {
    error.value = 'Добавьте текст ответа.'
    return
  }

  saving.value = true
  error.value = ''

  try {
    const post = await api.post<ForumPost>(`/api/v1/forum/topics/${props.topicId}/posts`, {
      forum_post: {
        body: body.value.trim(),
        quoted_post_id: props.quote?.post.id ?? null,
        quote_text: props.quote?.text || null,
      },
    })

    body.value = ''
    emit('posted', post)
    emit('cancel-quote')
  }
  catch (err) {
    error.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

defineExpose({ focus })
</script>

<template>
  <section ref="container" class="card card-pad forum-composer">
    <div class="row-between mb-16">
      <h2 class="section-title" style="margin-bottom: 0;">
        Ответить
      </h2>
      <span class="muted small">Markdown, как в дневниках</span>
    </div>

    <div v-if="quote" class="forum-composer-quote">
      <div class="row-between mb-8">
        <span class="forum-quote-author">
          Цитата: {{ quoteAuthor }}<template v-if="quote?.text"> · фрагмент</template>
        </span>
        <button type="button" class="btn btn-ghost btn-sm" @click="emit('cancel-quote')">
          Убрать
        </button>
      </div>
      <p class="muted small">{{ quotePreview }}</p>
    </div>

    <div v-if="error" class="form-error">
      {{ error }}
    </div>

    <MarkdownEditor
      id="forum-reply"
      v-model="body"
      :rows="10"
      :maxlength="20000"
      placeholder="Ваш ответ…"
    />

    <div class="row mt-16">
      <button class="btn btn-primary" :disabled="saving" @click="submit">
        {{ saving ? 'Отправляем…' : 'Отправить' }}
      </button>
    </div>
  </section>
</template>
