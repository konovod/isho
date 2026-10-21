<script setup lang="ts">
import type { ForumMeta, ForumPost, ForumTopic } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

interface TopicResponse {
  topic: ForumTopic
  items: ForumPost[]
  meta: ForumMeta
}

const route = useRoute()
const api = useApi()
const { user, canModerate } = useAuth()
const { dateTime, plural } = useFormat()

const sectionSlug = computed(() => route.params.section as string)
const topicSlug = computed(() => route.params.topic as string)
const page = computed(() => Math.max(1, Number(route.query.page) || 1))

const { data, pending, error, refresh } = await useAsyncData(
  `forum-topic-${sectionSlug.value}-${topicSlug.value}`,
  () => api.get<TopicResponse>(`/api/v1/forum/sections/${sectionSlug.value}/topics/${topicSlug.value}?page=${page.value}`),
  { watch: [page, sectionSlug, topicSlug] },
)

const topic = computed(() => data.value?.topic ?? null)
const posts = computed(() => data.value?.items ?? [])

if (!data.value && error.value) {
  throw createError({ statusCode: 404, statusMessage: 'Тема не найдена' })
}

const composer = ref<{ focus: () => void } | null>(null)
const quotedPost = ref<ForumPost | null>(null)
const actionError = ref('')

const editingTitle = ref(false)
const titleDraft = ref('')
const savingTitle = ref(false)

const isTopicAuthor = computed(() => !!user.value && user.value.id === topic.value?.author.id)
const canEditTopic = computed(() => !!user.value && (isTopicAuthor.value || canModerate.value))
const canDeleteTopic = computed(() => canModerate.value)

function startTitleEdit() {
  titleDraft.value = topic.value?.title ?? ''
  editingTitle.value = true
}

async function saveTitle() {
  if (!topic.value) return
  if (!titleDraft.value.trim()) {
    actionError.value = 'Укажите название темы.'
    return
  }

  savingTitle.value = true
  actionError.value = ''

  try {
    await api.patch<ForumTopic>(`/api/v1/forum/topics/${topic.value.id}`, {
      forum_topic: { title: titleDraft.value.trim() },
    })
    editingTitle.value = false
    await refresh()
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
  finally {
    savingTitle.value = false
  }
}

async function deleteTopic() {
  if (!topic.value) return
  if (!confirm(`Удалить тему «${topic.value.title}» вместе со всеми сообщениями?`)) return

  actionError.value = ''

  try {
    await api.del(`/api/v1/forum/topics/${topic.value.id}`)
    await navigateTo(`/forum/${sectionSlug.value}`)
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
}

function quote(post: ForumPost) {
  quotedPost.value = post
  composer.value?.focus()
}

function cancelQuote() {
  quotedPost.value = null
}

function onUpdated(updated: ForumPost) {
  if (!data.value) return
  data.value.items = data.value.items.map(post => (post.id === updated.id ? updated : post))
}

async function onPosted(post: ForumPost) {
  const current = data.value
  if (!current) return

  const totalAfter = current.topic.replies_count + 2
  const lastPage = Math.max(1, Math.ceil(totalAfter / current.meta.per_page))

  if (lastPage !== current.meta.page) {
    await navigateTo({
      path: route.path,
      query: { page: lastPage },
      hash: `#post-${post.id}`,
    })
    return
  }

  await refresh()
  await nextTick()
  document.getElementById(`post-${post.id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' })
}

async function onDeleted(post: ForumPost) {
  if (!confirm('Удалить это сообщение?')) return

  actionError.value = ''

  try {
    await api.del(`/api/v1/forum/posts/${post.id}`)
    const onlyPost = (data.value?.items.length ?? 0) === 1

    if (onlyPost && page.value > 1) {
      await navigateTo({ path: route.path, query: { page: page.value - 1 } })
    }
    else {
      await refresh()
    }
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
}

const description = computed(() => {
  const first = data.value?.items[0]
  const text = markdownToText(first?.body)
  return text.slice(0, 160) || topic.value?.title || `Обсуждение на форуме ${SITE_NAME}`
})

useSeoMeta({
  title: () => `${topic.value?.title || 'Тема'} — ${SITE_NAME}`,
  description: () => description.value,
})
</script>

<template>
  <div v-if="topic" class="container">
    <div class="row mb-16 forum-breadcrumbs">
      <NuxtLink to="/forum" class="muted small">Форум</NuxtLink>
      <span class="muted small">/</span>
      <NuxtLink :to="`/forum/${topic.section.slug}`" class="muted small">
        {{ topic.section.title }}
      </NuxtLink>
      <template v-if="topic.project">
        <span class="muted small">/</span>
        <NuxtLink :to="`/p/${topic.project.slug}`" class="muted small">
          {{ topic.project.title }}
        </NuxtLink>
      </template>
    </div>

    <div v-if="actionError" class="form-error">
      {{ actionError }}
    </div>

    <div class="page-head forum-topic-head">
      <div>
        <form v-if="editingTitle" class="forum-title-form" @submit.prevent="saveTitle">
          <input v-model="titleDraft" class="input" maxlength="160">
          <button class="btn btn-primary btn-sm" :disabled="savingTitle" type="submit">
            Сохранить
          </button>
          <button class="btn btn-ghost btn-sm" type="button" @click="editingTitle = false">
            Отмена
          </button>
        </form>
        <template v-else>
          <h1>{{ topic.title }}</h1>
          <p class="muted small mt-8">
            <NuxtLink :to="`/u/${topic.author.username}`">
              {{ topic.author.display_name || topic.author.username }}
            </NuxtLink>
            · {{ dateTime(topic.created_at) }}
            · {{ topic.replies_count }} {{ plural(topic.replies_count, 'ответ', 'ответа', 'ответов') }}
          </p>
        </template>
      </div>

      <div class="row">
        <button
          v-if="canEditTopic && !editingTitle"
          class="btn btn-ghost btn-sm"
          type="button"
          @click="startTitleEdit"
        >
          Изменить название
        </button>
        <button
          v-if="canDeleteTopic"
          class="btn btn-danger btn-sm"
          type="button"
          @click="deleteTopic"
        >
          Удалить тему
        </button>
      </div>
    </div>

    <div v-if="pending" class="empty">
      Загружаем сообщения…
    </div>

    <template v-else>
      <div class="forum-posts">
        <ForumPostItem
          v-for="post in posts"
          :key="post.id"
          :post="post"
          :current-user-id="user?.id"
          :can-moderate="canModerate"
          :is-first="page === 1 && post.id === posts[0]?.id"
          @quote="quote"
          @updated="onUpdated"
          @deleted="onDeleted"
        />
      </div>

      <ForumPagination
        :page="data?.meta.page || 1"
        :pages="data?.meta.pages || 1"
        :base-path="`/forum/${topic.section.slug}/${topic.slug}`"
      />

      <ForumComposer
        v-if="user"
        ref="composer"
        :topic-id="topic.id"
        :quote="quotedPost"
        class="mt-24"
        @posted="onPosted"
        @cancel-quote="cancelQuote"
      />

      <div v-else class="empty mt-24">
        <NuxtLink to="/sign_in" class="btn btn-primary btn-sm">
          Войдите, чтобы ответить
        </NuxtLink>
      </div>
    </template>

    <div class="mt-24">
      <NuxtLink :to="`/forum/${topic.section.slug}`" class="btn btn-ghost btn-sm">
        ← {{ topic.section.title }}
      </NuxtLink>
    </div>
  </div>
</template>
