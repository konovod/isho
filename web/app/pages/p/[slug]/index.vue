<script setup lang="ts">
import type { Devlog, ForumTopic, ProjectDetail, ProjectJamEntry } from '~/types/api'

const route = useRoute()
const api = useApi()
const { user, canModerate } = useAuth()
const { date } = useFormat()
const moderatedNotice = ref('')

const { data: project, error } = await useAsyncData(
  `project-${route.params.slug}`,
  () => api.get<ProjectDetail>(`/api/v1/projects/${route.params.slug}`),
)

const { data: devlogData } = await useAsyncData(
  `project-devlogs-${route.params.slug}`,
  () => api.get<{ items: Devlog[] }>(`/api/v1/projects/${route.params.slug}/devlogs`),
)

const { data: forumData } = await useAsyncData(
  `project-forum-${route.params.slug}`,
  () => api.get<{ items: ForumTopic[] }>(`/api/v1/projects/${route.params.slug}/forum/topics?per_page=3`),
)

const { data: jamsData } = await useAsyncData(
  `project-jams-${route.params.slug}`,
  () => api.get<{ items: ProjectJamEntry[] }>(`/api/v1/projects/${route.params.slug}/jams`),
)

const devlogs = computed(() => devlogData.value?.items ?? [])
const forumTopics = computed(() => forumData.value?.items ?? [])
const projectJams = computed(() => jamsData.value?.items ?? [])

if (!project.value) {
  throw createError({ statusCode: 404, statusMessage: 'Проект не найден' })
}

const isOwner = computed(() => user.value?.id === project.value?.author.id)
const authorName = computed(() => project.value?.author.display_name || project.value?.author.username || '')
const kindLabel = computed(() => {
  const labels: Record<string, string> = { game: 'Игра', tool: 'Инструмент', asset: 'Ассет' }
  return labels[project.value?.kind ?? ''] ?? project.value?.kind ?? ''
})
const initials = computed(() => authorName.value.slice(0, 2))
const aiUsage = computed(() => aiUsageOption(project.value?.ai_usage))
const playableBuild = computed(() => project.value?.builds.find(build => build.kind === 'web' && build.play_url) ?? null)
const canFeed = computed(() => !!project.value && project.value.status === 'published' && !project.value.nsfw)
const feedUrl = computed(() => `/api/v1/feeds/projects/${project.value?.slug}/devlogs.rss`)
const feedTitle = computed(() => `${SITE_NAME} — дневник «${project.value?.title || ''}»`)

function onModerated(updated: ProjectDetail) {
  project.value = updated
  moderatedNotice.value = 'Проект снят с публикации. Причина сохранена и видна автору в редакторе.'
}

useSeoMeta({
  title: () => `${project.value?.title} — ${SITE_NAME}`,
  description: () => project.value?.tagline || markdownToText(project.value?.description).slice(0, 160),
  ogTitle: () => project.value?.title,
  ogDescription: () => project.value?.tagline || '',
  ogImage: () => project.value?.cover_url || undefined,
})

useHead(() => ({
  link: canFeed.value
    ? [{ rel: 'alternate', type: 'application/rss+xml', title: feedTitle.value, href: feedUrl.value }]
    : [],
}))
</script>

<template>
  <div v-if="project">
    <div class="project-hero" :class="{ 'project-hero-empty': !project.cover_url }">
      <img v-if="project.cover_url" :src="project.cover_url" :alt="project.title">
    </div>

    <div class="container">
      <div class="project-head">
        <div>
          <div class="row mb-8">
            <span class="badge" :class="project.status === 'published' ? 'badge-published' : 'badge-draft'">
              {{ project.status === 'published' ? 'Опубликован' : 'Черновик' }}
            </span>
            <span class="muted small">{{ kindLabel }}</span>
            <span v-if="project.nsfw" class="badge badge-nsfw">18+</span>
            <span class="badge badge-ai" :title="aiUsage.description">ИИ: {{ aiUsage.label }}</span>
          </div>

          <h1 class="project-title">
            {{ project.title }}
          </h1>

          <p v-if="project.tagline" class="muted" style="margin-top: 8px; font-size: 17px;">
            {{ project.tagline }}
          </p>
        </div>

        <div class="row" style="margin-left: auto;">
          <RssLink v-if="canFeed" :href="feedUrl" :title="feedTitle" />
          <NuxtLink
            v-if="playableBuild"
            :to="`/p/${project.slug}/play/${playableBuild.id}`"
            class="btn btn-primary btn-sm"
          >
            Играть
          </NuxtLink>
          <NuxtLink v-if="isOwner" :to="`/dashboard/projects/${project.slug}/edit`" class="btn btn-ghost btn-sm">
            Редактировать
          </NuxtLink>
        </div>
      </div>

      <div v-if="canModerate && project.status === 'published'" class="card card-pad moderation-panel">
        <h2 class="section-title" style="margin-bottom: 4px;">
          Модерация
        </h2>
        <p class="muted small mb-16">
          Снимите проект с публикации, указав причину. Автор увидит её в редакторе и сможет опубликовать проект снова.
        </p>
        <ModerationUnpublish :slug="project.slug" @done="onModerated" />
      </div>

      <div v-if="moderatedNotice" class="form-success mt-16">
        {{ moderatedNotice }}
      </div>

      <div class="project-layout">
        <div>
          <ScreenshotGallery
            v-if="project.screenshots.length"
            :screenshots="project.screenshots"
            :title="project.title"
          />

          <section class="section" style="padding-top: 22px;">
            <h2 class="section-title">
              Об игре
            </h2>
            <MarkdownBody v-if="project.description" :source="project.description" />
            <p v-else class="description">
              Автор пока не добавил описание.
            </p>
          </section>

          <section v-if="devlogs.length" class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Дневник
            </h2>

            <div class="devlog-feed">
              <article v-for="devlog in devlogs" :key="devlog.id" class="devlog-entry">
                <div class="row-between mb-8">
                  <h3 class="devlog-entry-title">
                    {{ devlog.title }}
                  </h3>
                  <span class="muted small">{{ date(devlog.created_at) }}</span>
                </div>

                <MarkdownBody v-if="!isLongDevlog(devlog.body)" :source="devlog.body" />

                <template v-else>
                  <p class="description devlog-entry-preview">
                    {{ devlogPreview(devlog.body) }}
                  </p>
                  <NuxtLink
                    :to="`/p/${project.slug}/devlog/${devlog.slug}`"
                    class="btn btn-ghost btn-sm mt-16"
                  >
                    Читать целиком
                  </NuxtLink>
                </template>
              </article>
            </div>
          </section>

          <section v-if="projectJams.length" class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Участие в джемах
            </h2>

            <div class="dash-list">
              <NuxtLink
                v-for="entry in projectJams"
                :key="entry.id"
                :to="`/jams/${entry.jam.slug}`"
                class="dash-row"
              >
                <div class="dash-info">
                  <div class="row mb-8">
                    <h3>{{ entry.jam.title }}</h3>
                    <JamPhaseBadge :phase="entry.jam.phase" />
                    <span v-if="entry.status === 'disqualified'" class="badge badge-disqualified">
                      снята
                    </span>
                  </div>
                  <div class="muted small">
                    {{ entry.status === 'disqualified'
                      ? (entry.disqualified_reason || 'Заявка снята организатором')
                      : 'Заявка подана' }}
                  </div>
                </div>
                <span class="forum-section-arrow">→</span>
              </NuxtLink>
            </div>
          </section>

          <section class="section" style="padding-top: 0;">
            <div class="row-between mb-16">
              <h2 class="section-title" style="margin-bottom: 0;">
                Обсуждение
              </h2>
              <NuxtLink :to="`/p/${project.slug}/forum`" class="btn btn-ghost btn-sm">
                Все темы
              </NuxtLink>
            </div>

            <ForumTopicList
              v-if="forumTopics.length"
              :topics="forumTopics"
              :show-project="false"
            />

            <div v-else class="card card-pad">
              <p class="muted">
                Вопросов по проекту пока нет. Спросите автора или начните обсуждение.
              </p>
              <NuxtLink :to="`/p/${project.slug}/forum/new`" class="btn btn-primary btn-sm mt-16">
                Задать вопрос
              </NuxtLink>
            </div>
          </section>

          <DownloadList
            class="mt-24"
            :downloads="project.downloads"
            :builds="project.builds"
            :slug="project.slug"
            :show-usage="isOwner"
          />
        </div>

        <aside class="project-sidebar">
          <div class="card card-pad">
            <div class="author-card">
              <span class="avatar">{{ initials }}</span>
              <div>
                <NuxtLink :to="`/u/${project.author.username}`" style="font-weight: 650;">
                  {{ authorName }}
                </NuxtLink>
                <div class="muted small">
                  @{{ project.author.username }}
                </div>
              </div>
            </div>

            <div v-if="project.author.bio" class="muted small mt-16">
              {{ project.author.bio }}
            </div>
          </div>

          <div v-if="project.tags.length" class="card card-pad">
            <h3 class="section-title" style="font-size: 14px;">
              Теги
            </h3>
            <div class="row">
              <NuxtLink
                v-for="tag in project.tags"
                :key="tag.id"
                :to="`/?tag=${tag.slug}`"
                class="tag"
              >
                {{ tag.name }}
              </NuxtLink>
            </div>
          </div>

          <div class="card card-pad">
            <h3 class="section-title" style="font-size: 14px;">
              Использование ИИ
            </h3>
            <div class="ai-usage-value">
              {{ aiUsage.label }}
            </div>
            <p class="muted small" style="margin-top: 4px;">
              {{ aiUsage.description }}
            </p>
          </div>

          <div class="card card-pad">
            <div v-if="project.status === 'published'" class="row-between small muted">
              <span>Опубликован</span>
              <span>{{ date(project.published_at) }}</span>
            </div>
            <div v-else class="row-between small muted">
              <span>Черновик</span>
              <span>виден только вам</span>
            </div>
          </div>
        </aside>
      </div>
    </div>
  </div>
</template>
