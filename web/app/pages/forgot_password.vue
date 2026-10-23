<script setup lang="ts">
import { formatApiError } from '~/composables/useApi'

const { requestPasswordReset } = useAuth()

const email = ref('')
const sent = ref(false)
const error = ref('')
const pending = ref(false)

useSeoMeta({
  title: () => `Сброс пароля — ${SITE_NAME}`,
  robots: 'noindex',
})

async function submit() {
  error.value = ''
  pending.value = true

  try {
    await requestPasswordReset(email.value.trim())
    sent.value = true
  }
  catch (err) {
    error.value = formatApiError(err, 'Не удалось отправить письмо')
  }
  finally {
    pending.value = false
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="card auth-card">
      <template v-if="sent">
        <h1>Проверьте почту</h1>
        <p class="sub">
          Если аккаунт с адресом <strong>{{ email.trim() }}</strong> существует, мы отправили
          ссылку для сброса пароля. Загляните и в «Спам».
        </p>
        <p class="sub">
          Ссылка действует 1 час и работает один раз.
        </p>

        <NuxtLink to="/sign_in" class="btn btn-primary w-full">
          Вернуться ко входу
        </NuxtLink>
      </template>

      <template v-else>
        <h1>Забыли пароль?</h1>
        <p class="sub">
          Укажите почту аккаунта — пришлём ссылку, по которой можно задать новый пароль.
        </p>

        <div v-if="error" class="form-error">
          {{ error }}
        </div>

        <form @submit.prevent="submit">
          <div class="field">
            <label class="label" for="email">Почта</label>
            <input id="email" v-model="email" class="input" type="email" autocomplete="email" required>
          </div>

          <button class="btn btn-primary w-full" type="submit" :disabled="pending">
            {{ pending ? 'Отправляем…' : 'Отправить ссылку' }}
          </button>
        </form>

        <p class="auth-switch">
          Вспомнили пароль?
          <NuxtLink to="/sign_in">
            Войти
          </NuxtLink>
        </p>
      </template>
    </div>
  </div>
</template>
