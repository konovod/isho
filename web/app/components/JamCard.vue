<script setup lang="ts">
import type { Jam } from '~/types/api'

defineProps<{
  jam: Jam
}>()

const { dateTimeIn } = useFormat()

function dateRange(jam: Jam): string {
  const start = jam.starts_at ? dateTimeIn(jam.starts_at, jam.time_zone) : '—'
  const end = jam.submissions_close_at ? dateTimeIn(jam.submissions_close_at, jam.time_zone) : '—'
  return `${start} — ${end}`
}
</script>

<template>
  <NuxtLink :to="`/jams/${jam.slug}`" class="jam-card">
    <div class="jam-card-banner">
      <img v-if="jam.banner_card_url || jam.banner_url" :src="jam.banner_card_url || jam.banner_url || ''" :alt="jam.title">
      <div v-else class="jam-card-banner-empty" aria-hidden="true">
        {{ jam.title.slice(0, 1) }}
      </div>
      <div class="jam-card-badges">
        <JamPhaseBadge :phase="jam.phase" />
      </div>
    </div>

    <div class="jam-card-body">
      <h2 class="jam-card-title">
        {{ jam.title }}
      </h2>
      <p v-if="jam.tagline" class="muted small">
        {{ jam.tagline }}
      </p>

      <div class="jam-card-theme">
        <template v-if="jam.theme">
          Тема: <strong>{{ jam.theme }}</strong>
        </template>
        <template v-else-if="jam.phase === 'upcoming'">
          Тема будет объявлена
        </template>
        <template v-else-if="jam.phase === 'draft'">
          Черновик виден только организатору
        </template>
      </div>

      <div class="jam-card-meta muted small">
        <span>{{ dateRange(jam) }}</span>
        <span>@{{ jam.organizer.username }}</span>
      </div>
    </div>
  </NuxtLink>
</template>
