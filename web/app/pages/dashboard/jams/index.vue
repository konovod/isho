<script setup lang="ts">
import type { Jam } from '~/types/api'

definePageMeta({ middleware: 'auth' })

const api = useApi()
const { dateTimeIn } = useFormat()

const { data, pending, error, refresh } = await useAsyncData(
  'my-jams',
  () => api.get<{ items: Jam[] }>('/api/v1/my_jams'),
)

const jams = computed(() => data.value?.items ?? [])

function dates(jam: Jam): string {
  if (!jam.starts_at || !jam.submissions_close_at) return 'Даты не заданы'

  return `${dateTimeIn(jam.starts_at, jam.time_zone)} — ${dateTimeIn(jam.submissions_close_at, jam.time_zone)}`
}
</script>

<template>
  <div class="container">
    <div class="page-head">
      <div>
        <h1>Мои джемы</h1>
        <p>Черновики видны только вам. После публикации джем появляется в разделе «Джемы» и на форуме.</p>
      </div>

      <NuxtLink to="/dashboard/jams/new" class="btn btn-primary">
        + Новый джем
      </NuxtLink>
    </div>

    <div v-if="pending" class="empty">
      Загружаем джемы…
    </div>

    <div v-else-if="error" class="empty">
      Не удалось загрузить джемы.
      <button class="btn btn-ghost btn-sm mt-16" @click="refresh()">
        Повторить
      </button>
    </div>

    <div v-else-if="!jams.length" class="empty">
      Здесь пока ничего нет. Создайте первый джем — черновик можно заполнять постепенно.
      <div class="mt-16">
        <NuxtLink to="/dashboard/jams/new" class="btn btn-primary btn-sm">
          Создать джем
        </NuxtLink>
      </div>
    </div>

    <div v-else class="dash-list">
      <div v-for="jam in jams" :key="jam.id" class="dash-row">
        <div class="dash-thumb">
          <img v-if="jam.banner_card_url || jam.banner_url" :src="jam.banner_card_url || jam.banner_url || ''" :alt="jam.title">
        </div>

        <div class="dash-info">
          <div class="row mb-8">
            <h3>{{ jam.title }}</h3>
            <JamPhaseBadge :phase="jam.phase" />
          </div>
          <div class="muted small">
            {{ dates(jam) }}
            <template v-if="jam.theme"> · тема: {{ jam.theme }}</template>
            <template v-if="jam.cancel_reason"> · причина отмены: {{ jam.cancel_reason }}</template>
          </div>
        </div>

        <div class="dash-actions">
          <NuxtLink :to="`/jams/${jam.slug}`" class="btn btn-ghost btn-sm">
            Открыть
          </NuxtLink>
          <NuxtLink :to="`/dashboard/jams/${jam.slug}/edit`" class="btn btn-ghost btn-sm">
            Редактировать
          </NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>
