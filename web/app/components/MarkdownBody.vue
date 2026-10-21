<script setup lang="ts">
const props = defineProps<{ source?: string | null }>()

const html = computed(() => renderMarkdown(props.source))
</script>

<template>
  <div class="markdown-body" v-html="html" />
</template>
