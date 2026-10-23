<script setup lang="ts">
import { ApiError } from '~/composables/useApi'

const { signIn } = useAuth()
const route = useRoute()
const router = useRouter()

const login = ref('')
const password = ref('')
const error = ref('')
const pending = ref(false)

async function submit() {
  error.value = ''
  pending.value = true

  try {
    const me = await signIn(login.value.trim(), password.value)
    await router.push(me.ban ? '/banned' : (route.query.redirect?.toString() || '/dashboard'))
  }
  catch (err) {
    error.value = err instanceof ApiError
      ? (err.code === 'validation_failed' ? 'Неверная почта, ник или пароль' : err.message)
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
          <label class="label" for="login">Почта или ник</label>
          <input
            id="login"
            v-model="login"
            class="input"
            type="text"
            autocomplete="username"
            autocapitalize="none"
            spellcheck="false"
            placeholder="you@example.com или ваш_ник"
            required
          >
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
        <NuxtLink to="/forgot_password">
          Забыли пароль?
        </NuxtLink>
      </p>

      <p class="auth-switch">
        Нет аккаунта?
        <NuxtLink to="/sign_up">
          Зарегистрироваться
        </NuxtLink>
      </p>
    </div>
  </div>
</template>
