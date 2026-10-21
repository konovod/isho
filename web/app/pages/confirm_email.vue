<script setup lang="ts">
import { formatApiError } from '~/composables/useApi'

const route = useRoute()
const api = useApi()
const { user, fetchMe } = useAuth()

const state = ref<'pending' | 'done' | 'error'>('pending')
const email = ref('')
const error = ref('')

// The token is consumed by the API call below, which runs only in the browser:
// mail clients that preload the link must not use it up.
const token = computed(() => (route.query.token as string | undefined) ?? '')

useSeoMeta({
  title: () => `Подтверждение почты — ${SITE_NAME}`,
  robots: 'noindex',
})

onMounted(async () => {
  if (!token.value) {
    state.value = 'error'
    error.value = 'В ссылке нет кода подтверждения.'
    return
  }

  try {
    const result = await api.post<{ confirmed: boolean, email: string }>(
      '/api/v1/email_confirmations',
      { token: token.value },
    )

    email.value = result.email
    state.value = 'done'

    if (user.value) await fetchMe(true)
  }
  catch (err) {
    state.value = 'error'
    error.value = formatApiError(err, 'Не удалось подтвердить почту')
  }
})
</script>

<template>
  <div class="auth-wrap">
    <div class="card auth-card">
      <template v-if="state === 'pending'">
        <h1>Подтверждаем почту</h1>
        <p class="sub">
          Секунду…
        </p>
      </template>

      <template v-else-if="state === 'done'">
        <h1>Почта подтверждена</h1>
        <p class="sub">
          Адрес <strong>{{ email }}</strong> подтверждён. Теперь можно публиковать проекты и писать на форуме.
        </p>

        <NuxtLink v-if="user" to="/dashboard" class="btn btn-primary w-full">
          Перейти в кабинет
        </NuxtLink>
        <NuxtLink v-else to="/sign_in" class="btn btn-primary w-full">
          Войти
        </NuxtLink>
      </template>

      <template v-else>
        <h1>Не удалось подтвердить почту</h1>
        <p class="sub">
          {{ error }}
        </p>

        <NuxtLink v-if="user" to="/dashboard" class="btn btn-ghost w-full">
          В кабинет — отправить письмо ещё раз
        </NuxtLink>
        <NuxtLink v-else to="/sign_in" class="btn btn-ghost w-full">
          Войти
        </NuxtLink>
      </template>
    </div>
  </div>
</template>
