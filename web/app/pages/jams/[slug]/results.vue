<script setup lang="ts">
import type { JamResults } from '~/types/api'

const route = useRoute()
const api = useApi()
const { dateTimeIn, plural } = useFormat()
const slug = computed(() => route.params.slug as string)

const { data, pending, error } = await useAsyncData(
  () => `jam-results-${slug.value}`,
  () => api.get<JamResults>(`/api/v1/jams/${slug.value}/results`),
  { watch: [slug] },
)

const results = computed(() => data.value ?? null)
const items = computed(() => results.value?.items ?? [])

function date(value: string | null | undefined): string {
  return results.value ? dateTimeIn(value, results.value.jam.time_zone) : '—'
}

function placeLabel(place: number | null): string {
  if (!place) return '—'
  return `${place} место по баллам`
}

useSeoMeta({
  title: () => `Итоги — ${results.value?.jam.title || 'джем'} — ${SITE_NAME}`,
})
</script>

<template>
  <div class="container">
    <div v-if="pending" class="empty">
      Загружаем итоги…
    </div>

    <div v-else-if="error || !results" class="empty">
      Не удалось загрузить итоги.
      <div class="mt-16">
        <NuxtLink :to="`/jams/${slug}`" class="btn btn-ghost btn-sm">
          Вернуться к джему
        </NuxtLink>
      </div>
    </div>

    <template v-else>
      <div class="row mb-16 forum-breadcrumbs">
        <NuxtLink to="/jams" class="muted small">← Джемы</NuxtLink>
        <span class="muted small">/</span>
        <NuxtLink :to="`/jams/${results.jam.slug}`" class="muted small">{{ results.jam.title }}</NuxtLink>
      </div>

      <div class="page-head">
        <div>
          <div class="row mb-8">
            <h1>Итоги</h1>
            <JamPhaseBadge :phase="results.jam.phase" />
          </div>
          <p class="muted small">
            {{ results.jam.title }} · шкала 1–{{ results.jam.score_scale }}
          </p>
        </div>

        <NuxtLink :to="`/jams/${results.jam.slug}`" class="btn btn-ghost">
          К джему
        </NuxtLink>
      </div>

      <div class="card card-pad jam-mode-note mb-16">
        <strong>Итоговые баллы: {{ jamJudgingModeLabel(results.jam.judging_mode) }}</strong>
        <p class="muted small">
          {{ jamJudgingModeHint(results.jam.judging_mode) }}
        </p>
      </div>

      <div v-if="!results.available" class="empty">
        <template v-if="results.jam.phase === 'canceled'">
          Джем отменён, итоги не подводятся.
        </template>
        <template v-else>
          Итоги откроются после окончания судейства — {{ date(results.jam.voting_closes_at) }}.
        </template>
      </div>

      <template v-else>
        <section v-if="results.jam.results_note" class="section" style="padding-top: 0;">
          <h2 class="section-title">
            Победители и итоги
          </h2>
          <MarkdownBody :source="results.jam.results_note" />
        </section>

        <div v-if="!items.length" class="empty">
          Оценок пока нет.
        </div>

        <template v-else>
          <p class="muted small mb-16">
            Места ниже считаются автоматически по сумме баллов. Официальных победителей объявляет администратор.
          </p>

          <div class="jam-results">
            <article
              v-for="item in items"
              :key="item.entry_id"
              class="card card-pad jam-result-row"
              :class="{ 'jam-result-winner': item.place === 1 }"
            >
              <div class="jam-result-place">
                {{ placeLabel(item.place) }}
              </div>

              <div class="dash-thumb">
                <img v-if="item.project.cover_url" :src="item.project.cover_url" :alt="item.project.title">
              </div>

              <div class="jam-result-main">
                <h3>
                  <NuxtLink :to="`/p/${item.project.slug}`">
                    {{ item.project.title }}
                  </NuxtLink>
                </h3>
                <p v-if="item.project.tagline" class="muted small">
                  {{ item.project.tagline }}
                </p>
                <div class="muted small">
                  {{ item.votes_count }} {{ plural(item.votes_count, 'оценка', 'оценки', 'оценок') }}
                </div>
              </div>

              <div class="jam-result-score">
                <strong>{{ item.total }}</strong>
                <span class="muted small">из {{ item.max_total }}</span>
              </div>

              <div class="jam-result-criteria">
                <span v-for="criterion in item.criteria" :key="criterion.criterion_id" class="jam-result-criterion">
                  {{ criterion.title }}: {{ criterion.average }}
                </span>
              </div>
            </article>
          </div>
        </template>

        <p class="muted small mt-16">
          Индивидуальные отзывы по критериям видны авторам заявок.
        </p>
      </template>
    </template>
  </div>
</template>
