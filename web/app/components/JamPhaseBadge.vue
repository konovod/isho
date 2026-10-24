<script setup lang="ts">
import type { JamPhase } from '~/types/api'

const props = defineProps<{
  phase: JamPhase
}>()

const labels: Record<JamPhase, string> = {
  draft: 'Черновик',
  upcoming: 'Скоро',
  open: 'Приём заявок',
  judging: 'Судейство',
  finished: 'Завершён',
  canceled: 'Отменён',
}

const label = computed(() => labels[props.phase] ?? props.phase)
</script>

<template>
  <span class="badge jam-phase-badge" :class="`jam-phase-${phase}`">
    {{ label }}
  </span>
</template>
