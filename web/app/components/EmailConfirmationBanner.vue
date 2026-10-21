<script setup lang="ts">
const { user, emailConfirmed } = useAuth()
const { pending, message, error, cooldown, cooldownLabel, resend } = useEmailConfirmation()

const route = useRoute()

// The sign-up card and the confirmation page already talk about the letter.
const visible = computed(() =>
  !!user.value
  && !emailConfirmed.value
  && !['/sign_up', '/confirm_email'].includes(route.path),
)
</script>

<template>
  <div v-if="visible" class="container">
    <div class="notice notice-warn">
      <div class="notice-body">
        <div class="notice-title">
          Подтвердите почту
        </div>
        <div class="notice-text">
          Мы отправили письмо на <strong>{{ user?.email }}</strong>.
          Пока адрес не подтверждён, публиковать проекты и писать на форуме нельзя.
        </div>
        <div v-if="message" class="notice-text notice-text-success">
          {{ message }}
        </div>
        <div v-if="error" class="notice-text notice-text-error">
          {{ error }}
        </div>
      </div>

      <button class="btn btn-sm btn-ghost notice-action" :disabled="pending || cooldown > 0" @click="resend">
        <template v-if="pending">
          Отправляем…
        </template>
        <template v-else-if="cooldown > 0">
          Повтор через {{ cooldownLabel }}
        </template>
        <template v-else>
          Отправить ещё раз
        </template>
      </button>
    </div>
  </div>
</template>
