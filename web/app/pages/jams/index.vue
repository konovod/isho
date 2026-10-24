<script setup lang="ts">
import type { JamList } from '~/types/api'

const route = useRoute()
const api = useApi()
const { user } = useAuth()

const phases = ['upcoming', 'open', 'judging', 'finished'] as const
type PhaseFilter = typeof phases[number] | 'all'

const tabs: Array<{ value: PhaseFilter, label: string }> = [
  { value: 'all', label: 'Все' },
  { value: 'open', label: 'Приём заявок' },
  { value: 'judging', label: 'Судейство' },
  { value: 'upcoming', label: 'Скоро' },
  { value: 'finished', label: 'Завершённые' },
]

const phase = computed<PhaseFilter>(() => {
  const value = String(route.query.phase || '')
  return phases.includes(value as typeof phases[number]) ? value as PhaseFilter : 'all'
})
const page = computed(() => Math.max(1, Number(route.query.page) || 1))
const userKey = computed(() => user.value?.id ?? 'guest')

const { data, pending, error, refresh } = await useAsyncData(
  () => `jams-${phase.value}-${page.value}-${userKey.value}`,
  () => api.get<JamList>('/api/v1/jams', {
    phase: phase.value === 'all' ? undefined : phase.value,
    page: page.value,
  }),
  { watch: [phase, page, userKey] },
)

const jams = computed(() => data.value?.items ?? [])

useSeoMeta({
  title: `Джемы — ${SITE_NAME}`,
  description: `Игровые джемы и конкурсы ${SITE_NAME}: правила, сроки, заявки и итоги.`,
})
</script>

<template>
  <div class="container">
    <div class="page-head">
      <div>
        <h1>Джемы</h1>
        <p>Соревнования по разработке игр: тема, правила, сроки и итоги.</p>
      </div>

      <NuxtLink v-if="user" to="/dashboard/jams/new" class="btn btn-primary">
        + Новый джем
      </NuxtLink>
    </div>

    <div class="editor-tabs jam-tabs">
      <NuxtLink
        v-for="tab in tabs"
        :key="tab.value"
        :to="tab.value === 'all' ? '/jams' : `/jams?phase=${tab.value}`"
        class="editor-tab"
        :class="{ active: phase === tab.value }"
      >
        {{ tab.label }}
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
      {{ phase === 'all'
        ? 'Джемов пока нет. Создайте первый.'
        : 'В этой категории пока нет джемов.' }}
    </div>

    <template v-else>
      <div class="jam-grid">
        <JamCard v-for="jam in jams" :key="jam.id" :jam="jam" />
      </div>

      <ForumPagination
        :page="data?.meta.page || 1"
        :pages="data?.meta.pages || 1"
        base-path="/jams"
        :query="phase === 'all' ? {} : { phase }"
      />
    </template>
  </div>
</template>
