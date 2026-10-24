<script setup lang="ts">
const props = defineProps<{
  target: string | null
  label?: string
}>()

const mounted = ref(false)
const now = ref(Date.now())
let timer: number | null = null

const remaining = computed(() => {
  if (!props.target) return 0
  return Math.max(0, new Date(props.target).getTime() - now.value)
})

const text = computed(() => {
  const total = Math.floor(remaining.value / 1000)
  if (total <= 0) return ''

  const days = Math.floor(total / 86_400)
  const hours = Math.floor((total % 86_400) / 3_600)
  const minutes = Math.floor((total % 3_600) / 60)
  const seconds = total % 60

  const parts: string[] = []
  if (days > 0) parts.push(`${days} д`)
  if (hours > 0 || days > 0) parts.push(`${hours} ч`)
  if (minutes > 0 || hours > 0 || days > 0) parts.push(`${minutes} мин`)
  parts.push(`${seconds} с`)

  return parts.join(' ')
})

onMounted(() => {
  mounted.value = true
  timer = window.setInterval(() => {
    now.value = Date.now()
  }, 1000)
})

onUnmounted(() => {
  if (timer !== null) window.clearInterval(timer)
})
</script>

<template>
  <div v-if="mounted && text" class="jam-countdown">
    <span v-if="label" class="muted small">{{ label }}</span>
    <strong>{{ text }}</strong>
  </div>
</template>
