<script setup lang="ts">
import type { ProjectCard } from '~/types/api'

const props = defineProps<{ project: ProjectCard }>()

const initials = computed(() => props.project.title.slice(0, 2))
const author = computed(() => props.project.author.display_name || props.project.author.username)
</script>

<template>
  <NuxtLink :to="`/p/${project.slug}`" class="project-card">
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
      <div class="project-meta">
        <span>{{ author }}</span>
        <template v-if="project.tags.length">
          <span>·</span>
          <span>{{ project.tags.slice(0, 2).map(tag => tag.name).join(', ') }}</span>
        </template>
      </div>
    </div>
  </NuxtLink>
</template>
