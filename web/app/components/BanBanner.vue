<script setup lang="ts">
const { user } = useAuth()
const { dateTime } = useFormat()
const route = useRoute()

const visible = computed(() => !!user.value?.ban && route.path !== '/banned')
</script>

<template>
  <div v-if="visible" class="container">
    <div class="notice notice-error">
      <div class="notice-body">
        <div class="notice-title">
          Аккаунт забанен
        </div>
        <div class="notice-text">
          {{ user?.ban?.reason }} · до {{ dateTime(user?.ban?.banned_until) }}
        </div>
      </div>

      <NuxtLink to="/banned" class="btn btn-sm btn-ghost notice-action">
        Подробнее
      </NuxtLink>
    </div>
  </div>
</template>
