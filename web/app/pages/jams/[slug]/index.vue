<script setup lang="ts">
import type { Jam, JamEntry, JamEntryList } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const route = useRoute()
const api = useApi()
const { user } = useAuth()
const { dateTimeIn, plural } = useFormat()

const slug = computed(() => route.params.slug as string)
const userKey = computed(() => user.value?.id ?? 'guest')

const { data: jam, error, refresh: refreshJam } = await useAsyncData(
  () => `jam-${slug.value}-${userKey.value}`,
  () => api.get<Jam>(`/api/v1/jams/${slug.value}`),
  { watch: [slug, userKey] },
)

const { data: entriesData, refresh: refreshEntries } = await useAsyncData(
  () => `jam-entries-${slug.value}-${userKey.value}`,
  () => api.get<JamEntryList>(`/api/v1/jams/${slug.value}/entries?per_page=6`),
  { watch: [slug, userKey] },
)

if (!jam.value && error.value) {
  throw createError({ statusCode: 404, statusMessage: 'Джем не найден' })
}

const criteria = computed(() => jam.value?.criteria ?? [])
const forumSection = computed(() => jam.value?.forum_section ?? null)
const canEdit = computed(() => !!jam.value?.viewer?.can_edit)
const canSubmit = computed(() => !!jam.value?.viewer?.can_submit)
const canScore = computed(() => !!jam.value?.viewer?.can_score)
const myEntries = computed(() => jam.value?.viewer?.my_entries ?? [])
const entries = computed(() => entriesData.value?.items ?? [])
const entriesTotal = computed(() => entriesData.value?.meta.total ?? jam.value?.entries_count ?? 0)
const organizerName = computed(() => jam.value?.organizer.display_name || jam.value?.organizer.username || '')
const organizerInitials = computed(() => organizerName.value.slice(0, 2))
const showSubmit = ref(false)
const feedbackOpen = ref<number | null>(null)
const notice = ref('')
const actionError = ref('')

const nextLabel = computed(() => {
  switch (jam.value?.phase) {
    case 'upcoming': return 'До старта'
    case 'open': return 'До конца приёма заявок'
    case 'judging': return 'До конца судейства'
    default: return ''
  }
})

function time(value: string | null | undefined): string {
  return jam.value ? dateTimeIn(value, jam.value.time_zone) : '—'
}

async function refreshAll() {
  await Promise.all([refreshJam(), refreshEntries()])
  await refreshNuxtData()
}

async function onSubmitted(_entry: JamEntry) {
  showSubmit.value = false
  actionError.value = ''
  notice.value = 'Заявка подана'
  await refreshAll()
}

async function withdraw(entry: JamEntry) {
  if (!confirm(`Отозвать заявку «${entry.project.title}»?`)) return

  actionError.value = ''
  notice.value = ''

  try {
    await api.del(`/api/v1/jams/${slug.value}/entries/${entry.id}`)
    notice.value = 'Заявка отозвана'
    await refreshAll()
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
}

function toggleFeedback(entry: JamEntry) {
  feedbackOpen.value = feedbackOpen.value === entry.id ? null : entry.id
}

useSeoMeta({
  title: () => `${jam.value?.title || 'Джем'} — ${SITE_NAME}`,
  description: () => jam.value?.tagline || markdownToText(jam.value?.description).slice(0, 160),
  ogTitle: () => jam.value?.title,
  ogDescription: () => jam.value?.tagline || '',
  ogImage: () => jam.value?.banner_url || undefined,
})
</script>

<template>
  <div v-if="jam">
    <div class="project-hero jam-hero" :class="{ 'project-hero-empty': !jam.banner_url }">
      <img v-if="jam.banner_url" :src="jam.banner_url" :alt="jam.title">
    </div>

    <div class="container">
      <div class="row mb-16 forum-breadcrumbs">
        <NuxtLink to="/jams" class="muted small">
          ← Джемы
        </NuxtLink>
      </div>

      <div class="project-head">
        <div>
          <div class="row mb-8">
            <JamPhaseBadge :phase="jam.phase" />
            <span v-if="jam.phase === 'draft'" class="muted small">виден только организатору</span>
            <span v-if="jam.canceled_at" class="muted small">отменён</span>
          </div>

          <h1 class="project-title">
            {{ jam.title }}
          </h1>

          <p v-if="jam.tagline" class="muted" style="margin-top: 8px; font-size: 17px;">
            {{ jam.tagline }}
          </p>
        </div>

        <div class="row" style="margin-left: auto;">
          <NuxtLink v-if="canEdit" :to="`/dashboard/jams/${jam.slug}/edit`" class="btn btn-ghost btn-sm">
            Управление
          </NuxtLink>
          <NuxtLink
            v-if="forumSection"
            :to="`/forum/${forumSection.slug}`"
            class="btn btn-ghost btn-sm"
          >
            Обсуждение
          </NuxtLink>
        </div>
      </div>

      <div v-if="jam.phase === 'canceled'" class="form-error mt-16">
        Джем отменён.<template v-if="jam.cancel_reason"> Причина: {{ jam.cancel_reason }}</template>
      </div>
      <div v-else-if="jam.phase === 'draft'" class="card card-pad mt-16">
        <p class="muted">
          Это черновик. Организатор видит его только здесь и в панели управления.
        </p>
      </div>

      <div class="project-layout">
        <div>
          <section class="section" style="padding-top: 22px;">
            <div class="row-between mb-16">
              <h2 class="section-title" style="margin-bottom: 0;">
                Сроки
              </h2>
              <span class="muted small">{{ jam.time_zone }}</span>
            </div>

            <div class="card card-pad jam-timeline-card">
              <JamTimeline :jam="jam" />
              <JamCountdown :target="jam.next_phase_at" :label="nextLabel" />
            </div>
          </section>

          <section class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Тема
            </h2>

            <div class="jam-theme">
              <template v-if="jam.theme">
                {{ jam.theme }}
              </template>
              <template v-else-if="jam.phase === 'upcoming'">
                Тема будет объявлена на старте — {{ time(jam.starts_at) }}.
              </template>
              <template v-else-if="jam.phase === 'draft'">
                Тема пока не объявлена.
              </template>
              <template v-else>
                Без отдельной темы.
              </template>
            </div>
          </section>

          <section v-if="jam.description" class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Описание
            </h2>
            <MarkdownBody :source="jam.description" />
          </section>

          <section v-if="jam.rules" class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Правила
            </h2>
            <MarkdownBody :source="jam.rules" />
          </section>

          <section v-if="jam.prizes" class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Призы
            </h2>
            <MarkdownBody :source="jam.prizes" />
          </section>

          <section class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Критерии оценки
            </h2>

            <div class="card card-pad jam-mode-note mb-16">
              <div class="row-between mb-8">
                <strong>Итоговые баллы: {{ jamJudgingModeLabel(jam.judging_mode) }}</strong>
              </div>
              <p class="muted small">
                {{ jamJudgingModeHint(jam.judging_mode) }}
              </p>
            </div>

            <div v-if="criteria.length" class="jam-criteria">
              <div v-for="criterion in criteria" :key="criterion.id" class="card card-pad">
                <div class="row-between mb-8">
                  <h3>{{ criterion.title }}</h3>
                  <span v-if="criterion.weight !== 1" class="muted small">вес ×{{ criterion.weight }}</span>
                </div>
                <p v-if="criterion.description" class="muted small">
                  {{ criterion.description }}
                </p>
              </div>
            </div>

            <div v-else-if="canEdit" class="card card-pad">
              <p class="muted">
                Критериев пока нет. Добавьте их в панели управления — без них джем нельзя опубликовать.
              </p>
              <NuxtLink :to="`/dashboard/jams/${jam.slug}/edit`" class="btn btn-primary btn-sm mt-16">
                Добавить критерии
              </NuxtLink>
            </div>

            <div v-else class="empty">
              Критерии пока не объявлены.
            </div>
          </section>

          <section class="section" style="padding-top: 0;">
            <div class="row-between mb-16">
              <h2 class="section-title" style="margin-bottom: 0;">
                Заявки ({{ entriesTotal }})
              </h2>
              <NuxtLink
                v-if="entriesTotal > entries.length"
                :to="`/jams/${jam.slug}/entries`"
                class="btn btn-ghost btn-sm"
              >
                Все заявки
              </NuxtLink>
            </div>

            <div v-if="notice" class="form-success mb-16">
              {{ notice }}
            </div>
            <div v-if="actionError" class="form-error mb-16">
              {{ actionError }}
            </div>

            <div v-if="jam.phase === 'open'" class="card card-pad mb-16">
              <template v-if="user">
                <template v-if="canSubmit">
                  <p class="muted small">
                    Можно подать несколько проектов. Один проект — одна заявка в этом джеме.
                  </p>
                  <button
                    v-if="!showSubmit"
                    class="btn btn-primary mt-16"
                    type="button"
                    @click="showSubmit = true"
                  >
                    Подать заявку
                  </button>
                </template>
                <p v-else class="muted small">
                  Подача недоступна: подтвердите почту или проверьте статус аккаунта.
                </p>
              </template>
              <template v-else>
                <p class="muted">
                  Войдите, чтобы подать проект в джем.
                </p>
                <NuxtLink to="/sign_in" class="btn btn-primary btn-sm mt-16">
                  Войти
                </NuxtLink>
              </template>
            </div>
            <div v-else-if="jam.phase === 'upcoming'" class="card card-pad mb-16 muted">
              Приём заявок начнётся {{ time(jam.starts_at) }}.
            </div>
            <div v-else-if="jam.phase === 'judging' || jam.phase === 'finished'" class="card card-pad mb-16 muted">
              Приём заявок закрыт.
            </div>

            <div v-if="jam.phase === 'judging'" class="card card-pad mb-16">
              <template v-if="user">
                <template v-if="canScore">
                  <p class="muted small">
                    Судейство идёт. Оцените заявки по критериям и оставьте текстовый отзыв — он важнее баллов.
                  </p>
                  <NuxtLink :to="`/jams/${jam.slug}/judge`" class="btn btn-primary mt-16">
                    Оценить заявки
                  </NuxtLink>
                </template>
                <p v-else class="muted small">
                  Голосование недоступно: подтвердите почту или проверьте статус аккаунта.
                </p>
              </template>
              <template v-else>
                <p class="muted">
                  Войдите, чтобы оценить заявки и оставить отзывы.
                </p>
                <NuxtLink to="/sign_in" class="btn btn-primary btn-sm mt-16">
                  Войти
                </NuxtLink>
              </template>
            </div>

            <JamSubmitForm
              v-if="showSubmit"
              :jam-slug="jam.slug"
              class="mb-24"
              @submitted="onSubmitted"
              @cancel="showSubmit = false"
            />

            <div v-if="myEntries.length" class="card card-pad mb-16">
              <h3 class="section-title" style="font-size: 15px;">
                Ваши заявки
              </h3>

              <template v-for="entry in myEntries" :key="entry.id">
                <div class="jam-my-entry">
                  <NuxtLink :to="`/p/${entry.project.slug}`" class="jam-my-entry-title">
                    {{ entry.project.title }}
                  </NuxtLink>
                  <span v-if="entry.status === 'disqualified'" class="badge badge-disqualified">
                    снята
                  </span>
                  <span v-if="entry.disqualified_reason" class="muted small">
                    {{ entry.disqualified_reason }}
                  </span>
                  <button
                    v-if="jam.phase === 'open'"
                    class="btn btn-ghost btn-sm"
                    type="button"
                    @click="withdraw(entry)"
                  >
                    Отозвать
                  </button>
                  <button
                    v-if="jam.phase === 'finished'"
                    class="btn btn-ghost btn-sm"
                    type="button"
                    @click="toggleFeedback(entry)"
                  >
                    Обратная связь
                  </button>
                </div>

                <JamFeedbackPanel
                  v-if="feedbackOpen === entry.id"
                  :jam-slug="jam.slug"
                  :entry-id="entry.id"
                  class="mb-16"
                />
              </template>
            </div>

            <div v-if="entries.length" class="grid">
              <ProjectCard
                v-for="entry in entries"
                :key="entry.id"
                :project="entry.project"
              />
            </div>
            <div v-else class="empty">
              {{ jam.phase === 'open' ? 'Заявок пока нет. Будьте первым.' : 'Заявок пока нет.' }}
            </div>

            <NuxtLink
              v-if="entriesTotal > entries.length"
              :to="`/jams/${jam.slug}/entries`"
              class="btn btn-ghost btn-sm mt-16"
            >
              Все заявки ({{ entriesTotal }})
            </NuxtLink>
          </section>

          <section v-if="jam.phase === 'finished'" class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Итоги
            </h2>

            <MarkdownBody v-if="jam.results_note" :source="jam.results_note" />
            <div v-else class="empty">
              Победителей объявляет администратор. Баллы и места уже доступны.
            </div>

            <NuxtLink :to="`/jams/${jam.slug}/results`" class="btn btn-primary btn-sm mt-16">
              Все баллы и места
            </NuxtLink>
          </section>

          <section v-if="forumSection" class="section" style="padding-top: 0;">
            <h2 class="section-title">
              Обсуждение
            </h2>
            <div class="card card-pad">
              <p class="muted">
                Вопросы, поиск команды и новости джема — в разделе форума.
              </p>
              <NuxtLink :to="`/forum/${forumSection.slug}`" class="btn btn-primary btn-sm mt-16">
                Перейти в раздел
              </NuxtLink>
            </div>
          </section>
        </div>

        <aside class="project-sidebar">
          <div class="card card-pad">
            <div class="author-card">
              <span class="avatar">{{ organizerInitials }}</span>
              <div>
                <NuxtLink :to="`/u/${jam.organizer.username}`" style="font-weight: 650;">
                  {{ organizerName }}
                </NuxtLink>
                <div class="muted small">
                  @{{ jam.organizer.username }}
                </div>
              </div>
            </div>

            <div v-if="jam.organizer.bio" class="muted small mt-16">
              {{ jam.organizer.bio }}
            </div>
          </div>

          <div class="card card-pad">
            <h3 class="section-title" style="font-size: 14px;">
              Сроки
            </h3>
            <div class="jam-sidebar-row">
              <span class="muted small">Старт</span>
              <span>{{ time(jam.starts_at) }}</span>
            </div>
            <div class="jam-sidebar-row">
              <span class="muted small">Заявки до</span>
              <span>{{ time(jam.submissions_close_at) }}</span>
            </div>
            <div class="jam-sidebar-row">
              <span class="muted small">Судейство до</span>
              <span>{{ time(jam.voting_closes_at) }}</span>
            </div>
          </div>

          <div class="card card-pad">
            <h3 class="section-title" style="font-size: 14px;">
              Тема джема
            </h3>
            <div v-if="jam.theme" class="jam-sidebar-theme">
              {{ jam.theme }}
            </div>
            <p v-else class="muted small" style="margin-top: 4px;">
              {{ jam.phase === 'upcoming' ? 'Будет объявлена на старте.' : 'Пока не объявлена.' }}
            </p>
          </div>

          <div class="card card-pad">
            <h3 class="section-title" style="font-size: 14px;">
              Оценка
            </h3>
            <div class="muted small">
              Шкала: 1–{{ jam.score_scale }} · {{ criteria.length }}
              {{ plural(criteria.length, 'критерий', 'критерия', 'критериев') }}
            </div>
            <div class="muted small" style="margin-top: 4px;">
              Баллы: {{ jamJudgingModeLabel(jam.judging_mode) }}
            </div>
          </div>
        </aside>
      </div>
    </div>
  </div>
</template>
