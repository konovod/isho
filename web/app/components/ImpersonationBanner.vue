<script setup lang="ts">
const { user, impersonating, stopImpersonation } = useAuth()

const pending = ref(false)

async function backToAdmin() {
  pending.value = true

  try {
    await stopImpersonation()
    // A full reload drops the pages and lists built for the other account.
    window.location.href = '/moderation'
  }
  finally {
    pending.value = false
  }
}
</script>

<template>
  <div v-if="impersonating" class="container">
    <div class="notice notice-warn">
      <div class="notice-body">
        <div class="notice-title">
          Вы смотрите сайт от имени @{{ user?.username }}
        </div>
        <div class="notice-text">
          Вход администратора @{{ user?.impersonation?.admin.username }}.
          Изменения недоступны: в этом режиме можно только смотреть.
        </div>
      </div>

      <button class="btn btn-sm btn-ghost notice-action" :disabled="pending" @click="backToAdmin">
        <template v-if="pending">
          Возвращаемся…
        </template>
        <template v-else>
          Вернуться
        </template>
      </button>
    </div>
  </div>
</template>
