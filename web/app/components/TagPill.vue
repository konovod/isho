<script setup lang="ts">
import type { Tag } from '~/types/api'

defineProps<{ tag: Tag, active?: boolean }>()
</script>

<template>
  <NuxtLink
    :to="active ? '/' : `/?tag=${tag.slug}`"
    class="tag"
    :class="{ active }"
  >
    {{ tag.name }}
  </NuxtLink>
</template>
