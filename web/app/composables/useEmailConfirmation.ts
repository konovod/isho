import { formatApiError } from '~/composables/useApi'

/**
 * Shared "send the confirmation letter again" state for the dashboard banner
 * and the sign-up success card. The server owns the cooldown; the timer here
 * only keeps the button honest between requests.
 */
export function useEmailConfirmation() {
  const { user, fetchMe, resendEmailConfirmation } = useAuth()

  const pending = ref(false)
  const message = ref('')
  const error = ref('')
  const cooldown = ref(0)
  let timer: ReturnType<typeof setInterval> | null = null

  function stopTimer() {
    if (timer) {
      clearInterval(timer)
      timer = null
    }
  }

  function startCooldown(seconds: number) {
    stopTimer()
    cooldown.value = Math.max(0, Math.ceil(seconds))

    if (!cooldown.value) return

    timer = setInterval(() => {
      cooldown.value -= 1
      if (cooldown.value <= 0) stopTimer()
    }, 1000)
  }

  const cooldownLabel = computed(() => {
    const minutes = Math.floor(cooldown.value / 60)
    const seconds = cooldown.value % 60
    return `${minutes}:${String(seconds).padStart(2, '0')}`
  })

  async function resend() {
    pending.value = true
    error.value = ''
    message.value = ''

    try {
      const result = await resendEmailConfirmation()

      if (result.already_confirmed) {
        await fetchMe(true)
        message.value = 'Почта уже подтверждена.'
        return
      }

      startCooldown(result.retry_after ?? 300)
      message.value = result.sent
        ? `Письмо отправлено на ${user.value?.email ?? 'вашу почту'}. Загляните и в «Спам».`
        : 'Письмо уже отправлено — проверьте почту.'
    }
    catch (err) {
      error.value = formatApiError(err, 'Не удалось отправить письмо')
    }
    finally {
      pending.value = false
    }
  }

  onUnmounted(stopTimer)

  return { pending, message, error, cooldown, cooldownLabel, resend }
}
