<script setup lang="ts">
defineProps<{ href: string, title?: string }>()
</script>

<template>
  <a
    class="rss-link"
    :href="href"
    :title="title || 'RSS-лента'"
    aria-label="RSS-лента"
  >
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M4 11a9 9 0 0 1 9 9" />
      <path d="M4 4a16 16 0 0 1 16 16" />
      <circle cx="5" cy="19" r="1.6" />
    </svg>
    <span>RSS</span>
  </a>
</template>
