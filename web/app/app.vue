<script setup lang="ts">
const THEME_COLORS = { dark: '#0f1116', light: '#f6f7fb' } as const
const siteName = SITE_NAME

const { user, fetchMe } = useAuth()
const { theme, applyUserTheme } = useTheme()

// The account setting wins over the device cookie as soon as `me` arrives.
watch(
  () => user.value?.theme,
  value => applyUserTheme(value),
  { immediate: true, flush: 'sync' },
)

useHead(() => {
  const value = theme.value

  return {
    htmlAttrs: value ? { 'data-theme': value } : {},
    // Visitors without a saved choice follow the OS, so keep both variants
    // and let the browser pick the one that matches.
    meta: value
      ? [{ key: 'theme-color', name: 'theme-color', content: THEME_COLORS[value] }]
      : [
          { key: 'theme-color-dark', name: 'theme-color', content: THEME_COLORS.dark, media: '(prefers-color-scheme: dark)' },
          { key: 'theme-color-light', name: 'theme-color', content: THEME_COLORS.light, media: '(prefers-color-scheme: light)' },
        ],
  }
})

await fetchMe()
</script>

<template>
  <div class="shell">
    <AppHeader />

    <main class="main">
      <NuxtPage />
    </main>

    <footer class="footer">
      <div class="container">
        {{ siteName }} — прототип витрины игр. Crystal + Nuxt.
      </div>
    </footer>
  </div>
</template>
