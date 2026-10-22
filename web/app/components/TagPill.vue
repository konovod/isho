<script setup lang="ts">
import type { Tag } from '~/types/api'

defineProps<{ tag: Tag, active?: boolean, count?: number }>()

const { plural } = useFormat()
</script>

<template>
  <NuxtLink
    :to="active ? '/' : `/?tag=${tag.slug}`"
    class="tag"
    :class="{ active }"
  >
    {{ tag.name }}
    <span
      v-if="count && count > 0"
      class="tag-count"
      :title="`${count} ${plural(count, 'проект', 'проекта', 'проектов')}`"
    >
      {{ count }}
    </span>
  </NuxtLink>
</template>
