<script setup lang="ts">
import { ApiError } from '~/composables/useApi'

const { signIn } = useAuth()
const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref('')
const pending = ref(false)

async function submit() {
  error.value = ''
  pending.value = true

  try {
    await signIn(email.value.trim(), password.value)
    await router.push(route.query.redirect?.toString() || '/dashboard')
  }
  catch (err) {
    error.value = err instanceof ApiError
      ? (err.code === 'validation_failed' ? 'Неверная почта или пароль' : err.message)
      : 'Не удалось войти'
  }
  finally {
    pending.value = false
  }
}
</script>

<template>
  <div class="auth-wrap">
    <div class="card auth-card">
      <h1>Вход</h1>
      <p class="sub">
        С возвращением. Продолжим с того места, где остановились.
      </p>

      <div v-if="error" class="form-error">
        {{ error }}
      </div>

      <form @submit.prevent="submit">
        <div class="field">
          <label class="label" for="email">Почта</label>
          <input id="email" v-model="email" class="input" type="email" autocomplete="email" required>
        </div>

        <div class="field">
          <label class="label" for="password">Пароль</label>
          <input id="password" v-model="password" class="input" type="password" autocomplete="current-password" required>
        </div>

        <button class="btn btn-primary w-full" type="submit" :disabled="pending">
          {{ pending ? 'Входим…' : 'Войти' }}
        </button>
      </form>

      <p class="auth-switch">
        Нет аккаунта?
        <NuxtLink to="/sign_up">
          Зарегистрироваться
        </NuxtLink>
      </p>
    </div>
  </div>
</template>
