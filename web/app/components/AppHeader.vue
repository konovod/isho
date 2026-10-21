<script setup lang="ts">
const { user, signOut } = useAuth()
const router = useRouter()

const initials = computed(() => {
  const name = user.value?.display_name || user.value?.username || '?'
  return name.slice(0, 2)
})

async function logout() {
  await signOut()
  router.push('/')
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
        <NuxtLink v-if="user" to="/dashboard" class="nav-link">
          Мои проекты
        </NuxtLink>
      </nav>

      <div class="header-actions">
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
