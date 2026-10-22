<script setup lang="ts">
const THEME_COLORS = { dark: '#0f1116', light: '#f6f7fb' } as const
const siteName = SITE_NAME

const { user, loaded, fetchMe } = useAuth()
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

// Guests have no session cookie, so /me would only return 401. Skip that
// round-trip during SSR; the serialized `loaded` flag tells the client there
// is nothing to fetch either. Signed-in visitors still get a server-rendered
// header with their name and moderation links.
if (import.meta.server) {
  const cookie = useRequestHeaders(['cookie']).cookie ?? ''

  if (/(?:^|;\s*)isho_auth=/.test(cookie)) {
    await fetchMe()
  }
  else {
    loaded.value = true
  }
}
</script>

<template>
  <div class="shell">
    <AppHeader />

    <main class="main">
      <EmailConfirmationBanner />
      <NuxtPage />
    </main>

    <footer class="footer">
      <div class="container">
        {{ siteName }} — прототип витрины игр. Crystal + Nuxt.
      </div>
    </footer>
  </div>
</template>
