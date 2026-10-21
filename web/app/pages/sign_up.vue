<script setup lang="ts">
import { formatApiError } from '~/composables/useApi'

const { signUp } = useAuth()
const router = useRouter()
const {
  pending: resendPending,
  message: resendMessage,
  error: resendError,
  cooldown,
  cooldownLabel,
  resend,
} = useEmailConfirmation()

const email = ref('')
const username = ref('')
const displayName = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const error = ref('')
const pending = ref(false)
const created = ref(false)

async function submit() {
  error.value = ''
  pending.value = true

  try {
    await signUp({
      email: email.value.trim(),
      username: username.value.trim().toLowerCase(),
      display_name: displayName.value.trim() || undefined,
      password: password.value,
      password_confirmation: passwordConfirmation.value,
    })
    created.value = true
  }
  catch (err) {
    error.value = formatApiError(err, 'Не удалось создать аккаунт')
  }
  finally {
    pending.value = false
  }
}

async function goToDashboard() {
  await router.push('/dashboard')
}
</script>

<template>
  <div class="auth-wrap">
    <div v-if="created" class="card auth-card">
      <h1>Проверьте почту</h1>
      <p class="sub">
        Аккаунт создан. Мы отправили письмо на <strong>{{ email.trim() }}</strong> — откройте ссылку из него.
      </p>
      <p class="sub">
        Пока адрес не подтверждён, публиковать проекты и писать на форуме нельзя.
      </p>

      <div v-if="resendMessage" class="form-success">
        {{ resendMessage }}
      </div>
      <div v-if="resendError" class="form-error">
        {{ resendError }}
      </div>

      <button class="btn btn-ghost w-full" :disabled="resendPending || cooldown > 0" @click="resend">
        <template v-if="resendPending">
          Отправляем…
        </template>
        <template v-else-if="cooldown > 0">
          Отправить ещё раз через {{ cooldownLabel }}
        </template>
        <template v-else>
          Отправить письмо ещё раз
        </template>
      </button>

      <button class="btn btn-primary w-full mt-16" @click="goToDashboard">
        Перейти в кабинет
      </button>
    </div>

    <div v-else class="card auth-card">
      <h1>Регистрация</h1>
      <p class="sub">
        Аккаунт нужен, чтобы публиковать проекты и собирать аудиторию.
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
          <label class="label" for="username">Никнейм</label>
          <input
            id="username"
            v-model="username"
            class="input"
            type="text"
            autocomplete="username"
            pattern="[a-z0-9_]{3,32}"
            placeholder="game_dev"
            required
          >
          <span class="hint">3–32 символа: a-z, 0-9 и _. Попадёт в адрес профиля.</span>
        </div>

        <div class="field">
          <label class="label" for="display_name">Отображаемое имя <span class="muted">(необязательно)</span></label>
          <input id="display_name" v-model="displayName" class="input" type="text" autocomplete="name">
        </div>

        <div class="field">
          <label class="label" for="password">Пароль</label>
          <input id="password" v-model="password" class="input" type="password" autocomplete="new-password" minlength="10" required>
          <span class="hint">Минимум 10 символов.</span>
        </div>

        <div class="field">
          <label class="label" for="password_confirmation">Пароль ещё раз</label>
          <input id="password_confirmation" v-model="passwordConfirmation" class="input" type="password" autocomplete="new-password" minlength="10" required>
        </div>

        <button class="btn btn-primary w-full" type="submit" :disabled="pending">
          {{ pending ? 'Создаём…' : 'Создать аккаунт' }}
        </button>
      </form>

      <p class="auth-switch">
        Уже есть аккаунт?
        <NuxtLink to="/sign_in">
          Войти
        </NuxtLink>
      </p>
    </div>
  </div>
</template>
