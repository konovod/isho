<script setup lang="ts">
const { user, canModerate, signOut, saveTheme } = useAuth()
const { toggleTheme } = useTheme()
const router = useRouter()

const initials = computed(() => {
  const name = user.value?.display_name || user.value?.username || '?'
  return name.slice(0, 2)
})

async function logout() {
  await signOut()
  router.push('/')
}

async function onToggleTheme() {
  const next = toggleTheme()

  if (user.value) await saveTheme(next)
}
</script>

<template>
  <header class="site-header">
    <div class="container header-inner">
      <NuxtLink to="/" class="brand">
        <span class="brand-mark">◆</span>
        isho
      </NuxtLink>

      <nav class="nav">
        <NuxtLink to="/" class="nav-link">
          Каталог
        </NuxtLink>
        <NuxtLink to="/forum" class="nav-link">
          Форум
        </NuxtLink>
        <NuxtLink v-if="user" to="/dashboard" class="nav-link">
          Мои проекты
        </NuxtLink>
        <NuxtLink v-if="canModerate" to="/moderation" class="nav-link">
          Модерация
        </NuxtLink>
      </nav>

      <div class="header-actions">
        <button
          class="btn btn-ghost btn-sm btn-icon theme-toggle"
          type="button"
          aria-label="Переключить тему"
          title="Переключить тему"
          @click="onToggleTheme"
        >
          <svg
            class="icon-sun"
            viewBox="0 0 24 24"
            aria-hidden="true"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
          >
            <circle cx="12" cy="12" r="4" />
            <path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
          </svg>
          <svg
            class="icon-moon"
            viewBox="0 0 24 24"
            aria-hidden="true"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
          </svg>
        </button>

        <template v-if="user">
          <NuxtLink :to="`/u/${user.username}`" class="user-chip">
            <span class="avatar">{{ initials }}</span>
            <span>{{ user.display_name || user.username }}</span>
          </NuxtLink>
          <button class="btn btn-ghost btn-sm" @click="logout">
            Выйти
          </button>
        </template>
        <template v-else>
          <NuxtLink to="/sign_in" class="btn btn-ghost btn-sm">
            Войти
          </NuxtLink>
          <NuxtLink to="/sign_up" class="btn btn-primary btn-sm">
            Регистрация
          </NuxtLink>
        </template>
      </div>
    </div>
  </header>
</template>
