<script setup lang="ts">
import type { Screenshot } from '~/types/api'

const props = defineProps<{ screenshots: Screenshot[], title: string }>()

const activeId = ref<number | null>(props.screenshots[0]?.id ?? null)

const active = computed(() => {
  return props.screenshots.find(shot => shot.id === activeId.value) ?? props.screenshots[0]
})

watch(() => props.screenshots, (shots) => {
  if (!shots.some(shot => shot.id === activeId.value)) {
    activeId.value = shots[0]?.id ?? null
  }
}, { deep: true })
</script>

<template>
  <div v-if="screenshots.length">
    <div class="gallery-main">
      <img
        v-if="active?.url"
        :src="active.url"
        :alt="active.caption || title"
      >
    </div>

    <div v-if="screenshots.length > 1" class="gallery-thumbs">
      <button
        v-for="shot in screenshots"
        :key="shot.id"
        class="gallery-thumb"
        :class="{ active: shot.id === activeId }"
        type="button"
        @click="activeId = shot.id"
      >
        <img :src="shot.thumb_url || shot.url || ''" :alt="shot.caption || title" loading="lazy">
      </button>
    </div>
  </div>
</template>
