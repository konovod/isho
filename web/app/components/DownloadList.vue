<script setup lang="ts">
import type { Build, Download } from '~/types/api'

defineProps<{ downloads: Download[], builds?: Build[], slug?: string }>()
</script>

<template>
  <div v-if="(builds && builds.length) || downloads.length" class="card card-pad">
    <h2 class="section-title">
      Скачать
    </h2>

    <div v-for="item in builds" :key="`build-${item.id}`" class="download-row">
      <div>
        <div class="download-label">
          {{ item.label }}
        </div>
        <div class="row small muted" style="margin-top: 2px;">
          <span v-if="item.platform">{{ item.platform }}</span>
          <span v-if="item.platform && item.version">·</span>
          <span v-if="item.version">v{{ item.version }}</span>
          <span>{{ formatBytes(item.size_bytes) }}</span>
          <span class="badge" :class="item.kind === 'web' ? 'badge-published' : 'badge-draft'">
            {{ item.kind === 'web' ? 'в браузере' : 'файл' }}
          </span>
        </div>
      </div>

      <a
        v-if="item.kind === 'web' && item.play_url && slug"
        :href="`/p/${slug}/play/${item.id}`"
        class="btn btn-primary btn-sm"
        target="_blank"
        rel="noopener"
      >
        Играть
      </a>
      <a
        v-else-if="item.url"
        :href="item.url"
        class="btn btn-primary btn-sm"
      >
        Скачать
      </a>
    </div>

    <div v-for="item in downloads" :key="`download-${item.id}`" class="download-row">
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
