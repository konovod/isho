<script setup lang="ts">
definePageMeta({ middleware: 'auth' })

useSeoMeta({
  title: `Аккаунт забанен — ${SITE_NAME}`,
  description: 'Причина и срок блокировки аккаунта.',
})

const { user, fetchMe, signOut } = useAuth()
const { dateTime, plural } = useFormat()

const now = ref<number | null>(null)
const checking = ref(false)
let timer: ReturnType<typeof setInterval> | null = null

const ban = computed(() => user.value?.ban ?? null)
const until = computed(() => (ban.value ? new Date(ban.value.banned_until) : null))

const remaining = computed(() => {
  if (!until.value || now.value === null) return null
  return Math.max(0, until.value.getTime() - now.value)
})
const expired = computed(() => remaining.value === 0)
const days = computed(() => Math.floor((remaining.value ?? 0) / 86_400_000))
const hours = computed(() => Math.floor(((remaining.value ?? 0) % 86_400_000) / 3_600_000))
const minutes = computed(() => Math.floor(((remaining.value ?? 0) % 3_600_000) / 60_000))

if (!ban.value) {
  await navigateTo('/dashboard')
}

onMounted(() => {
  now.value = Date.now()
  timer = setInterval(() => {
    now.value = Date.now()
  }, 1000)
})

onBeforeUnmount(() => {
  if (timer) clearInterval(timer)
})

async function checkStatus() {
  checking.value = true

  try {
    await fetchMe(true)
    if (!user.value?.ban) await navigateTo('/dashboard')
  }
  finally {
    checking.value = false
  }
}

async function logout() {
  await signOut()
  await navigateTo('/')
}
</script>

<template>
  <div class="auth-wrap">
    <div class="card auth-card ban-card">
      <h1>Аккаунт забанен</h1>

      <template v-if="ban">
        <p class="sub">
          Публиковать проекты, дневники и сообщения на форуме нельзя до окончания блокировки.
        </p>

        <div class="ban-reason">
          <div class="muted small">
            Причина
          </div>
          <div class="ban-reason-text">
            {{ ban.reason }}
          </div>
        </div>

        <div class="ban-dates muted small">
          Выдан {{ dateTime(ban.banned_at) }} · до {{ dateTime(ban.banned_until) }}
        </div>

        <div v-if="expired" class="form-success ban-expired">
          Срок бана истёк. Обновите статус, чтобы вернуться в кабинет.
        </div>

        <div v-else-if="now === null" class="ban-countdown">
          <div class="ban-countdown-cell">
            <span class="ban-countdown-value">{{ ban.days_left }}</span>
            <span class="muted small">{{ plural(ban.days_left, 'день', 'дня', 'дней') }}</span>
          </div>
        </div>

        <div v-else class="ban-countdown" aria-live="polite">
          <div class="ban-countdown-cell">
            <span class="ban-countdown-value">{{ days }}</span>
            <span class="muted small">{{ plural(days, 'день', 'дня', 'дней') }}</span>
          </div>
          <div class="ban-countdown-cell">
            <span class="ban-countdown-value">{{ hours }}</span>
            <span class="muted small">{{ plural(hours, 'час', 'часа', 'часов') }}</span>
          </div>
          <div class="ban-countdown-cell">
            <span class="ban-countdown-value">{{ minutes }}</span>
            <span class="muted small">{{ plural(minutes, 'минута', 'минуты', 'минут') }}</span>
          </div>
        </div>

        <button class="btn btn-primary w-full mt-16" :disabled="checking" @click="checkStatus">
          {{ expired ? 'Вернуться в кабинет' : (checking ? 'Проверяем…' : 'Проверить статус') }}
        </button>
        <button class="btn btn-ghost w-full mt-16" :disabled="checking" @click="logout">
          Выйти из аккаунта
        </button>

        <p class="ban-hint muted small">
          Каталог и форум остаются доступны для чтения.
          <NuxtLink to="/">
            На главную
          </NuxtLink>
        </p>
      </template>
    </div>
  </div>
</template>
