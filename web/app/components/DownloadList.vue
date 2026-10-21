<script setup lang="ts">
import type { Download } from '~/types/api'

defineProps<{ downloads: Download[] }>()
</script>

<template>
  <div v-if="downloads.length" class="card card-pad">
    <h2 class="section-title">
      Скачать
    </h2>

    <div v-for="item in downloads" :key="item.id" class="download-row">
      <div>
        <div class="download-label">
          {{ item.label }}
        </div>
        <div class="row small muted" style="margin-top: 2px;">
          <span v-if="item.platform">{{ item.platform }}</span>
          <span v-if="item.platform && item.version">·</span>
          <span v-if="item.version">v{{ item.version }}</span>
          <span class="badge badge-external">внешняя ссылка</span>
        </div>
      </div>

      <a
        :href="item.url"
        class="btn btn-primary btn-sm"
        target="_blank"
        rel="noopener noreferrer nofollow"
      >
        Перейти
      </a>
    </div>
  </div>
</template>
