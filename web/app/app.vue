<script setup lang="ts">
const { fetchMe } = useAuth()

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
        isho — прототип витрины игр. Crystal + Nuxt.
      </div>
    </footer>
  </div>
</template>
