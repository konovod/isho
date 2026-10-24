<script setup lang="ts">
import type { Jam } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const api = useApi()
const router = useRouter()

const form = reactive({
  title: '',
  tagline: '',
  theme: '',
  description: '',
  starts_at: '',
  submissions_close_at: '',
  voting_closes_at: '',
  time_zone: 'Europe/Moscow',
})

const error = ref('')
const pending = ref(false)

function toIso(value: string): string | undefined {
  return zonedDateTimeToIso(value, form.time_zone)
}

async function submit() {
  error.value = ''
  pending.value = true

  try {
    const jam = await api.post<Jam>('/api/v1/jams', {
      jam: {
        title: form.title.trim(),
        tagline: form.tagline.trim() || undefined,
        theme: form.theme.trim() || undefined,
        description: form.description.trim() || undefined,
        starts_at: toIso(form.starts_at),
        submissions_close_at: toIso(form.submissions_close_at),
        voting_closes_at: toIso(form.voting_closes_at),
        time_zone: form.time_zone,
      },
    })

    await refreshNuxtData()
    await router.push(`/dashboard/jams/${jam.slug}/edit`)
  }
  catch (err) {
    error.value = formatApiError(err, 'Не удалось создать джем')
  }
  finally {
    pending.value = false
  }
}
</script>

<template>
  <div class="container">
    <div class="page-head">
      <div>
        <h1>Новый джем</h1>
        <p>Сначала создаётся черновик: даты, критерии и правила можно уточнить позже.</p>
      </div>
    </div>

    <div class="card card-pad" style="max-width: 720px;">
      <div v-if="error" class="form-error">
        {{ error }}
      </div>

      <form @submit.prevent="submit">
        <div class="field">
          <label class="label" for="jam-title">Название</label>
          <input id="jam-title" v-model="form.title" class="input" maxlength="120" required>
        </div>

        <div class="field">
          <label class="label" for="jam-tagline">Короткое описание</label>
          <input
            id="jam-tagline"
            v-model="form.tagline"
            class="input"
            maxlength="200"
            placeholder="Одна строка о джеме"
          >
        </div>

        <div class="field">
          <label class="label" for="jam-theme">Тема</label>
          <input
            id="jam-theme"
            v-model="form.theme"
            class="input"
            maxlength="200"
            placeholder="Например: «Это классика!»"
          >
          <span class="hint">До старта тема скрыта от гостей и участников.</span>
        </div>

        <div class="form-grid">
          <div class="field">
            <label class="label" for="jam-starts">Старт</label>
            <input id="jam-starts" v-model="form.starts_at" class="input" type="datetime-local">
          </div>

          <div class="field">
            <label class="label" for="jam-submissions">Приём заявок до</label>
            <input
              id="jam-submissions"
              v-model="form.submissions_close_at"
              class="input"
              type="datetime-local"
            >
          </div>
        </div>

        <div class="form-grid">
          <div class="field">
            <label class="label" for="jam-voting">Судейство до</label>
            <input
              id="jam-voting"
              v-model="form.voting_closes_at"
              class="input"
              type="datetime-local"
            >
          </div>

          <div class="field">
            <label class="label" for="jam-time-zone">Часовой пояс</label>
            <select id="jam-time-zone" v-model="form.time_zone" class="input">
              <option value="Europe/Moscow">Москва (UTC+3)</option>
              <option value="UTC">UTC</option>
              <option value="Europe/Kaliningrad">Калининград (UTC+2)</option>
              <option value="Asia/Yekaterinburg">Екатеринбург (UTC+5)</option>
              <option value="Asia/Novosibirsk">Новосибирск (UTC+7)</option>
              <option value="Asia/Vladivostok">Владивосток (UTC+10)</option>
            </select>
          </div>
        </div>

        <div class="field">
          <label class="label" for="jam-description">Описание</label>
          <MarkdownEditor
            id="jam-description"
            v-model="form.description"
            :maxlength="50000"
            :rows="10"
            placeholder="О чём джем, для кого, что важно знать. Поддерживается Markdown."
          />
        </div>

        <div class="row">
          <button class="btn btn-primary" type="submit" :disabled="pending">
            {{ pending ? 'Создаём…' : 'Создать черновик' }}
          </button>
          <NuxtLink to="/dashboard/jams" class="btn btn-ghost">
            Отмена
          </NuxtLink>
        </div>
      </form>
    </div>
  </div>
</template>
