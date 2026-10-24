<script setup lang="ts">
import type { Jam } from '~/types/api'

const props = defineProps<{
  jam: Jam
}>()

const { dateTimeIn } = useFormat()

const steps = computed(() => {
  const jam = props.jam
  const phase = jam.phase

  return [
    {
      key: 'upcoming',
      label: 'Старт и тема',
      at: jam.starts_at,
      done: ['open', 'judging', 'finished'].includes(phase),
      current: phase === 'upcoming',
    },
    {
      key: 'open',
      label: 'Приём заявок',
      at: jam.submissions_close_at,
      done: ['judging', 'finished'].includes(phase),
      current: phase === 'open',
    },
    {
      key: 'judging',
      label: 'Судейство',
      at: jam.voting_closes_at,
      done: phase === 'finished',
      current: phase === 'judging',
    },
    {
      key: 'finished',
      label: 'Итоги',
      at: null,
      done: phase === 'finished',
      current: phase === 'finished',
    },
  ]
})
</script>

<template>
  <ol class="jam-timeline">
    <li
      v-for="step in steps"
      :key="step.key"
      class="jam-timeline-step"
      :class="{ 'is-done': step.done, 'is-current': step.current }"
    >
      <span class="jam-timeline-dot" aria-hidden="true" />
      <div>
        <div class="jam-timeline-label">{{ step.label }}</div>
        <div class="muted small">
          {{ step.at ? dateTimeIn(step.at, jam.time_zone) : (jam.phase === 'finished' ? 'Опубликованы' : 'После судейства') }}
        </div>
      </div>
    </li>
  </ol>
</template>
