<script setup lang="ts">
import type { ProjectCard } from '~/types/api'

const props = defineProps<{ project: ProjectCard }>()

const initials = computed(() => props.project.title.slice(0, 2))
const author = computed(() => props.project.author.display_name || props.project.author.username)
const aiUsage = computed(() => aiUsageOption(props.project.ai_usage))
const devStatus = computed(() => devStatusLabel(props.project.dev_status))
const genre = computed(() => props.project.genre ? genreLabel(props.project.genre) : '')
const playUrl = computed(() => props.project.play_build_id
  ? `/p/${props.project.slug}/play/${props.project.play_build_id}`
  : null)
</script>

<template>
  <div class="project-card">
    <NuxtLink :to="`/p/${project.slug}`" class="project-card-link">
      <div class="project-cover">
        <img v-if="project.cover_url" :src="project.cover_url" :alt="project.title" loading="lazy">
        <div v-else class="cover-fallback">
          {{ initials }}
        </div>
      </div>

      <div class="project-body">
        <h3>{{ project.title }}</h3>
        <p v-if="project.tagline" class="muted small">
          {{ project.tagline }}
        </p>
        <div class="project-badges">
          <span class="badge badge-stage">{{ devStatus }}</span>
          <span v-if="project.nsfw" class="badge badge-nsfw" title="Только для взрослых">18+</span>
          <span class="badge badge-ai" :title="aiUsage.description">ИИ: {{ aiUsage.label }}</span>
        </div>
        <div class="project-meta">
          <span>{{ author }}</span>
          <template v-if="genre">
            <span>·</span>
            <span>{{ genre }}</span>
          </template>
          <template v-if="project.tags.length">
            <span>·</span>
            <span>{{ project.tags.slice(0, 2).map(tag => tag.name).join(', ') }}</span>
          </template>
        </div>
      </div>
    </NuxtLink>

    <NuxtLink
      v-if="playUrl"
      :to="playUrl"
      class="project-play"
      :aria-label="`Играть в ${project.title}`"
      title="Играть в браузере"
    >
      <svg class="project-play-icon" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">
        <path d="M8 5.5v13l11-6.5z" />
      </svg>
      Играть
    </NuxtLink>
  </div>
</template>
