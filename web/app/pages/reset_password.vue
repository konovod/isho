<script setup lang="ts">
import { formatApiError } from '~/composables/useApi'

const route = useRoute()
const { resetPassword } = useAuth()

const token = computed(() => (route.query.token as string | undefined) ?? '')
const state = ref<'form' | 'done' | 'missing'>(token.value ? 'form' : 'missing')

const password = ref('')
const passwordConfirmation = ref('')
const error = ref('')
const pending = ref(false)

useSeoMeta({
  title: () => `Новый пароль — ${SITE_NAME}`,
  robots: 'noindex',
})

async function submit() {
  error.value = ''

  if (password.value !== passwordConfirmation.value) {
    error.value = 'Пароли не совпадают.'
    return
  }

  pending.value = true

  try {
    // The call also starts a new session: the server closes every session
    // opened with the old password.
    await resetPassword(token.value, password.value, passwordConfirmation.value)
    state.value = 'done'
  }
  catch (err) {
    error.value = formatApiError(err, 'Не удалось изменить пароль')
  }
  finally {
    pending.value = false
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="card auth-card">
      <template v-if="state === 'missing'">
        <h1>Ссылка неполная</h1>
        <p class="sub">
          В адресе нет кода для сброса пароля. Запросите новое письмо — оно придёт на почту аккаунта.
        </p>

        <NuxtLink to="/forgot_password" class="btn btn-primary w-full">
          Запросить письмо
        </NuxtLink>
      </template>

      <template v-else-if="state === 'done'">
        <h1>Пароль изменён</h1>
        <p class="sub">
          Вы уже вошли в аккаунт. Остальные устройства потребуют новый пароль.
        </p>

        <NuxtLink to="/dashboard" class="btn btn-primary w-full">
          Перейти в кабинет
        </NuxtLink>
      </template>

      <template v-else>
        <h1>Новый пароль</h1>
        <p class="sub">
          Придумайте пароль для аккаунта. Длина — от 6 до 72 символов, состав любой.
        </p>

        <div v-if="error" class="form-error">
          {{ error }}
        </div>

        <form @submit.prevent="submit">
          <div class="field">
            <label class="label" for="password">Новый пароль</label>
            <input
              id="password"
              v-model="password"
              class="input"
              type="password"
              autocomplete="new-password"
              minlength="6"
              maxlength="72"
              required
            >
          </div>

          <div class="field">
            <label class="label" for="password_confirmation">Пароль ещё раз</label>
            <input
              id="password_confirmation"
              v-model="passwordConfirmation"
              class="input"
              type="password"
              autocomplete="new-password"
              minlength="6"
              maxlength="72"
              required
            >
          </div>

          <button class="btn btn-primary w-full" type="submit" :disabled="pending">
            {{ pending ? 'Сохраняем…' : 'Сохранить пароль' }}
          </button>
        </form>

        <p class="auth-switch">
          Ссылка не работает?
          <NuxtLink to="/forgot_password">
            Запросить новое письмо
          </NuxtLink>
        </p>
      </template>
    </div>
  </div>
</template>
