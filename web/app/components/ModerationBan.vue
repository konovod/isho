<script setup lang="ts">
import type { AdminUser, UserBanRecord } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = defineProps<{ user: AdminUser }>()
const emit = defineEmits<{ done: [user: AdminUser] }>()

const api = useApi()
const { date, dateTime } = useFormat()

const open = ref(false)
const reason = ref('')
const days = ref(7)
const error = ref('')
const saving = ref(false)

const historyOpen = ref(false)
const history = ref<UserBanRecord[]>([])
const historyPending = ref(false)
const historyError = ref('')

const banned = computed(() => !!props.user.ban)

function cancel() {
  open.value = false
  reason.value = ''
  days.value = 7
  error.value = ''
}

async function submitBan() {
  const text = reason.value.trim()

  if (!text) {
    error.value = 'Укажите причину.'
    return
  }

  saving.value = true
  error.value = ''

  try {
    const updated = await api.post<AdminUser>(`/api/v1/admin/users/${props.user.username}/ban`, {
      ban: { reason: text, days: Number(days.value) },
    })

    cancel()
    emit('done', updated)
    await syncHistory()
  }
  catch (err) {
    error.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

async function liftBan() {
  if (!confirm(`Снять бан с @${props.user.username}?`)) return

  saving.value = true
  error.value = ''

  try {
    const updated = await api.del<AdminUser>(`/api/v1/admin/users/${props.user.username}/ban`)
    emit('done', updated)
    await syncHistory()
  }
  catch (err) {
    error.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

async function toggleHistory() {
  historyOpen.value = !historyOpen.value

  if (historyOpen.value && !history.value.length) {
    await loadHistory()
  }
}

async function syncHistory() {
  history.value = []
  if (historyOpen.value) await loadHistory()
}

async function loadHistory() {
  historyPending.value = true
  historyError.value = ''

  try {
    const data = await api.get<{ items: UserBanRecord[] }>(`/api/v1/admin/users/${props.user.username}/bans`)
    history.value = data.items
  }
  catch (err) {
    historyError.value = formatApiError(err)
  }
  finally {
    historyPending.value = false
  }
}
</script>

<template>
  <div class="ban-manager">
    <div v-if="banned && user.ban" class="ban-status">
      <span class="badge badge-banned">забанен до {{ date(user.ban.banned_until) }}</span>
      <span class="muted small ban-status-reason">{{ user.ban.reason }}</span>
      <button class="btn btn-ghost btn-sm" type="button" :disabled="saving" @click="liftBan">
        Разбанить
      </button>
    </div>

    <button
      v-else-if="!open"
      class="btn btn-ghost btn-sm"
      type="button"
      @click="open = true"
    >
      Забанить
    </button>

    <form v-if="open" class="ban-form" @submit.prevent="submitBan">
      <div class="field">
        <label class="label" :for="`ban-reason-${user.id}`">Причина (увидит пользователь)</label>
        <textarea
          :id="`ban-reason-${user.id}`"
          v-model="reason"
          class="textarea textarea-sm"
          maxlength="500"
          rows="3"
          placeholder="Например: спам и оскорбления в форуме"
        />
      </div>

      <div class="field field-narrow">
        <label class="label" :for="`ban-days-${user.id}`">Срок, дней</label>
        <input
          :id="`ban-days-${user.id}`"
          v-model.number="days"
          class="input"
          type="number"
          min="1"
          max="3650"
          required
        >
      </div>

      <div class="row">
        <button class="btn btn-danger" type="submit" :disabled="saving || !reason.trim()">
          {{ saving ? 'Баним…' : 'Забанить' }}
        </button>
        <button class="btn btn-ghost" type="button" :disabled="saving" @click="cancel">
          Отмена
        </button>
      </div>
    </form>

    <div v-if="error" class="form-error mt-16">
      {{ error }}
    </div>

    <button class="btn btn-ghost btn-sm ban-history-toggle" type="button" @click="toggleHistory">
      {{ historyOpen ? 'Скрыть историю' : 'История банов' }}
    </button>

    <div v-if="historyOpen" class="ban-history">
      <div v-if="historyPending" class="muted small">
        Загружаем историю…
      </div>
      <div v-else-if="historyError" class="form-error">
        {{ historyError }}
      </div>
      <div v-else-if="!history.length" class="muted small">
        Банов не было.
      </div>
      <div v-else class="ban-history-list">
        <div v-for="item in history" :key="item.id" class="ban-history-item">
          <div class="row">
            <span class="badge" :class="item.active ? 'badge-banned' : 'badge-draft'">
              {{ item.active ? 'активен' : (item.lifted_at ? 'снят' : 'истёк') }}
            </span>
            <span class="muted small">
              {{ dateTime(item.banned_at) }} → {{ dateTime(item.expires_at) }}
            </span>
          </div>

          <div>{{ item.reason }}</div>

          <div class="muted small">
            Забанил @{{ item.banned_by || '—' }}
            <template v-if="item.lifted_at">
              · снял @{{ item.lifted_by || '—' }} {{ dateTime(item.lifted_at) }}
            </template>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
