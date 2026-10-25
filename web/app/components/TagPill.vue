<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router'

defineProps<{
  name: string
  to: RouteLocationRaw
  active?: boolean
  count?: number
}>()

const { plural } = useFormat()
</script>

<template>
  <NuxtLink
    :to="to"
    class="tag"
    :class="{ active }"
    :aria-current="active ? 'true' : undefined"
  >
    {{ name }}
    <span
      v-if="count && count > 0"
      class="tag-count"
      :title="`${count} ${plural(count, 'проект', 'проекта', 'проектов')}`"
    >
      {{ count }}
    </span>
    <span v-if="active" class="tag-x" aria-hidden="true">✕</span>
  </NuxtLink>
</template>
