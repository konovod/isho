<script setup lang="ts">
import type { JamFeedback } from '~/types/api'

const props = defineProps<{
  jamSlug: string
  entryId: number
}>()

const api = useApi()

const { data, pending, error } = await useAsyncData(
  `jam-feedback-${props.jamSlug}-${props.entryId}`,
  () => api.get<JamFeedback>(`/api/v1/jams/${props.jamSlug}/entries/${props.entryId}/feedback`),
)
</script>

<template>
  <div class="card card-pad jam-feedback">
    <div class="row-between mb-16">
      <h3 class="section-title" style="margin-bottom: 0;">
        Обратная связь
      </h3>
      <span v-if="data" class="muted small">
        учтено {{ data.counted_votes }} из {{ data.total_votes }}
      </span>
    </div>

    <div v-if="pending" class="empty">
      Загружаем отзывы…
    </div>

    <div v-else-if="error" class="empty">
      Отзывы пока недоступны.
    </div>

    <template v-else-if="data">
      <p class="muted small mb-16">
        {{ jamJudgingModeHint(data.mode) }}
      </p>

      <div class="jam-feedback-criteria">
        <section v-for="criterion in data.criteria" :key="criterion.id" class="jam-feedback-criterion">
          <div class="row-between mb-8">
            <h4>{{ criterion.title }}</h4>
            <span class="muted small">средний балл: {{ criterion.average }}</span>
          </div>

          <div v-if="criterion.items.length" class="jam-feedback-items">
            <div
              v-for="(item, index) in criterion.items"
              :key="index"
              class="jam-feedback-item"
              :class="{ 'not-counted': !item.counted }"
            >
              <div class="row">
                <span class="badge badge-published">{{ item.score }}</span>
                <span v-if="!item.counted" class="muted small">не идёт в итоги</span>
                <span v-if="item.voter" class="muted small">@{{ item.voter.username }}</span>
              </div>
              <p v-if="item.comment" class="jam-feedback-text">
                {{ item.comment }}
              </p>
              <p v-else class="muted small">
                Без текстового отзыва.
              </p>
            </div>
          </div>

          <p v-else class="muted small">
            Пока нет отзывов по этому критерию.
          </p>
        </section>
      </div>
    </template>
  </div>
</template>
