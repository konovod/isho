<script setup lang="ts">
import type { ProjectDetail } from '~/types/api'

const route = useRoute()
const api = useApi()

const { data: project } = await useAsyncData(
  `play-${route.params.slug}-${route.params.buildId}`,
  () => api.get<ProjectDetail>(`/api/v1/projects/${route.params.slug}`),
)

const build = computed(() => {
  const id = Number(route.params.buildId)
  return project.value?.builds.find(item => item.id === id && item.kind === 'web') ?? null
})

// A game on the site's own origin stays in an opaque sandbox (no cookies, no
// storage). On the separate media origin it may keep its own origin: that is
// what Unity needs for Cache Storage and PlayerPrefs, and that host has no
// session cookie to steal.
const IFRAME_SANDBOX = 'allow-scripts allow-forms allow-pointer-lock allow-modals allow-popups allow-downloads'
const pageOrigin = useRequestURL().origin
const iframeSandbox = computed(() => {
  const url = build.value?.play_url
  // A relative play URL is served by this same origin.
  if (!url || !/^https?:\/\//i.test(url)) return IFRAME_SANDBOX
  return new URL(url).origin === pageOrigin
    ? IFRAME_SANDBOX
    : `${IFRAME_SANDBOX} allow-same-origin`
})

if (!project.value || !build.value) {
  throw createError({ statusCode: 404, statusMessage: 'Сборка не найдена' })
}

useSeoMeta({
  title: () => `${project.value?.title ?? 'Игра'} — играть — ${SITE_NAME}`,
  description: () => project.value?.tagline || 'Игра в браузере.',
})
</script>

<template>
  <div v-if="project && build" class="container play-page">
    <div class="play-head">
      <div class="row">
        <NuxtLink :to="`/p/${project.slug}`" class="btn btn-ghost btn-sm">
          ← К проекту
        </NuxtLink>
        <span class="muted small">{{ project.title }} · {{ build.label }}</span>
      </div>

      <a
        v-if="build.play_url"
        :href="build.play_url"
        target="_blank"
        rel="noopener"
        class="btn btn-ghost btn-sm"
      >
        Открыть отдельно
      </a>
    </div>

    <p class="muted small play-hint">
      Игра работает в песочнице: она не видит ваш аккаунт, куки и данные сайта.
    </p>

    <iframe
      :src="build.play_url || ''"
      class="play-frame"
      title="Игра"
      :sandbox="iframeSandbox"
      allow="fullscreen; autoplay; gamepad"
      allowfullscreen
      referrerpolicy="no-referrer"
    />
  </div>
</template>
