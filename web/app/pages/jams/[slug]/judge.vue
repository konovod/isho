<script setup lang="ts">
import type { JamScoringEntry, JamScoringResponse, JamScoreValue } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const route = useRoute()
const api = useApi()
const slug = computed(() => route.params.slug as string)

const { data, pending, error: loadError, refresh } = await useAsyncData(
  () => `jam-scoring-${slug.value}`,
  () => api.get<JamScoringResponse>(`/api/v1/jams/${slug.value}/scoring`),
  { watch: [slug] },
)

const jam = computed(() => data.value?.jam ?? null)
const criteria = computed(() => jam.value?.criteria ?? [])
const items = computed(() => data.value?.items ?? [])
const progress = computed(() => data.value?.progress ?? { scored: 0, total: 0 })

const selectedId = ref<number | null>(null)
const draft = ref<Record<number, { score: number, comment: string }>>({})
const saving = ref(false)
const error = ref('')
const notice = ref('')

const selectedItem = computed<JamScoringEntry | null>(() => {
  return items.value.find(item => item.entry.id === selectedId.value) ?? null
})

const canSave = computed(() => {
  if (!selectedItem.value) return false
  return criteria.value.every(criterion => (draft.value[criterion.id]?.score ?? 0) >= 1)
})

function startScoring(item: JamScoringEntry) {
  selectedId.value = item.entry.id
  error.value = ''
  notice.value = ''

  const values: Record<number, { score: number, comment: string }> = {}

  for (const criterion of criteria.value) {
    const existing = item.my_scores.find(score => score.criterion_id === criterion.id)
    values[criterion.id] = {
      score: existing?.score ?? 0,
      comment: existing?.comment ?? '',
    }
  }

  draft.value = values
}

async function save() {
  const item = selectedItem.value
  if (!item || !canSave.value) return

  error.value = ''
  notice.value = ''
  saving.value = true

  try {
    const scores: JamScoreValue[] = criteria.value.map(criterion => ({
      criterion_id: criterion.id,
      score: draft.value[criterion.id]!.score,
      comment: draft.value[criterion.id]!.comment.trim() || null,
    }))

    await api.put(`/api/v1/jams/${slug.value}/entries/${item.entry.id}/scores`, {
      jam_scores: scores,
    })

    selectedId.value = null
    notice.value = 'Оценка сохранена'
    await refresh()
  }
  catch (err) {
    error.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

useSeoMeta({
  title: () => `Оценка заявок — ${jam.value?.title || 'джем'} — ${SITE_NAME}`,
})
</script>

<template>
  <div class="container">
    <div v-if="pending" class="empty">
      Загружаем заявки…
    </div>

    <div v-else-if="loadError || !jam" class="empty">
      Судейство недоступно: возможно, оно ещё не началось или уже закончилось.
      <div class="mt-16">
        <NuxtLink :to="`/jams/${slug}`" class="btn btn-ghost btn-sm">
          Вернуться к джему
        </NuxtLink>
      </div>
    </div>

    <template v-else>
      <div class="row mb-16 forum-breadcrumbs">
        <NuxtLink :to="`/jams/${jam.slug}`" class="muted small">← {{ jam.title }}</NuxtLink>
      </div>

      <div class="page-head">
        <div>
          <div class="row mb-8">
            <h1>Оценка заявок</h1>
            <JamPhaseBadge :phase="jam.phase" />
          </div>
          <p class="muted small">
            Оценено {{ progress.scored }} из {{ progress.total }}.
            Свои заявки оценивать нельзя.
          </p>
        </div>

        <JamCountdown :target="jam.next_phase_at" label="До конца судейства" />
      </div>

      <div class="card card-pad jam-mode-note mb-16">
        <strong>Итоговые баллы: {{ jamJudgingModeLabel(jam.judging_mode) }}</strong>
        <p class="muted small">
          {{ jamJudgingModeHint(jam.judging_mode) }}
        </p>
      </div>

      <div v-if="error" class="form-error">
        {{ error }}
      </div>
      <div v-if="notice" class="form-success">
        {{ notice }}
      </div>

      <div v-if="!items.length" class="empty">
        Нет заявок, которые можно оценить. Свои заявки в списке не показываются.
      </div>

      <div v-else class="dash-list">
        <div v-for="item in items" :key="item.entry.id" class="card card-pad">
          <div class="row-between">
            <div class="row" style="align-items: flex-start;">
              <div class="dash-thumb">
                <img
                  v-if="item.entry.project.cover_url"
                  :src="item.entry.project.cover_url"
                  :alt="item.entry.project.title"
                >
              </div>
              <div>
                <h3>
                  <NuxtLink :to="`/p/${item.entry.project.slug}`">
                    {{ item.entry.project.title }}
                  </NuxtLink>
                </h3>
                <p v-if="item.entry.project.tagline" class="muted small">
                  {{ item.entry.project.tagline }}
                </p>
                <div class="muted small">
                  @{{ item.entry.project.author.username }}
                </div>
              </div>
            </div>

            <div class="row">
              <span v-if="item.complete" class="badge badge-published">оценено</span>
              <button
                class="btn btn-ghost btn-sm"
                type="button"
                @click="startScoring(item)"
              >
                {{ item.complete ? 'Изменить оценку' : 'Оценить' }}
              </button>
            </div>
          </div>

          <form
            v-if="selectedId === item.entry.id"
            class="jam-score-form mt-16"
            @submit.prevent="save"
          >
            <div v-for="criterion in criteria" :key="criterion.id" class="jam-score-row">
              <div class="jam-score-criterion">
                <strong>{{ criterion.title }}</strong>
                <p v-if="criterion.description" class="muted small">
                  {{ criterion.description }}
                </p>
                <span class="muted small">вес ×{{ criterion.weight }}</span>
              </div>

              <div class="field field-narrow">
                <label class="label" :for="`score-${item.entry.id}-${criterion.id}`">Балл</label>
                <select
                  :id="`score-${item.entry.id}-${criterion.id}`"
                  v-model.number="draft[criterion.id]!.score"
                  class="input"
                >
                  <option :value="0">—</option>
                  <option v-for="value in jam.score_scale" :key="value" :value="value">
                    {{ value }}
                  </option>
                </select>
              </div>

              <div class="field jam-score-comment">
                <label class="label" :for="`comment-${item.entry.id}-${criterion.id}`">Отзыв</label>
                <textarea
                  :id="`comment-${item.entry.id}-${criterion.id}`"
                  v-model="draft[criterion.id]!.comment"
                  class="textarea textarea-sm"
                  maxlength="2000"
                  rows="3"
                  placeholder="Что понравилось и что улучшить. Отзыв увидит автор заявки."
                />
              </div>
            </div>

            <div class="row">
              <button class="btn btn-primary" type="submit" :disabled="saving || !canSave">
                {{ saving ? 'Сохраняем…' : 'Сохранить оценку' }}
              </button>
              <button class="btn btn-ghost" type="button" @click="selectedId = null">
                Отмена
              </button>
            </div>
          </form>
        </div>
      </div>

      <div class="row mt-24">
        <NuxtLink :to="`/jams/${jam.slug}/entries`" class="btn btn-ghost">
          Все заявки
        </NuxtLink>
        <NuxtLink :to="`/jams/${jam.slug}`" class="btn btn-ghost">
          К джему
        </NuxtLink>
      </div>
    </template>
  </div>
</template>
