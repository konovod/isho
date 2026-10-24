<script setup lang="ts">
import type { Jam, JamCriterion } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const route = useRoute()
const router = useRouter()
const api = useApi()
const { plural } = useFormat()
const slug = route.params.slug as string

const { data, pending, error: loadError, refresh } = await useAsyncData(
  `edit-jam-${slug}`,
  () => api.get<Jam>(`/api/v1/jams/${slug}`),
)

const jam = computed(() => data.value ?? null)
const criteria = computed(() => jam.value?.criteria ?? [])

const tab = ref<'details' | 'criteria' | 'publish'>('details')
const error = ref('')
const notice = ref('')
const saving = ref(false)
const uploading = ref(false)

const form = reactive({
  title: '',
  tagline: '',
  theme: '',
  description: '',
  rules: '',
  prizes: '',
  results_note: '',
  starts_at: '',
  submissions_close_at: '',
  voting_closes_at: '',
  time_zone: 'Europe/Moscow',
  judging_mode: 'community',
  score_scale: 5,
})

const criterionForm = reactive({
  title: '',
  description: '',
  weight: 1,
})

const editingCriterionId = ref<number | null>(null)
const criterionDraft = reactive({
  title: '',
  description: '',
  weight: 1,
})

watch(jam, (value) => {
  if (!value) return

  form.title = value.title
  form.tagline = value.tagline ?? ''
  form.theme = value.theme ?? ''
  form.description = value.description ?? ''
  form.rules = value.rules ?? ''
  form.prizes = value.prizes ?? ''
  form.results_note = value.results_note ?? ''
  form.time_zone = value.time_zone
  form.judging_mode = value.judging_mode
  form.score_scale = value.score_scale
  form.starts_at = isoToZonedDateTime(value.starts_at, value.time_zone)
  form.submissions_close_at = isoToZonedDateTime(value.submissions_close_at, value.time_zone)
  form.voting_closes_at = isoToZonedDateTime(value.voting_closes_at, value.time_zone)
}, { immediate: true })

function toIso(value: string): string | undefined {
  return zonedDateTimeToIso(value, form.time_zone)
}

function clearMessages() {
  error.value = ''
  notice.value = ''
}

function fail(err: unknown) {
  error.value = formatApiError(err)
}

async function save() {
  clearMessages()
  saving.value = true

  try {
    const updated = await api.patch<Jam>(`/api/v1/jams/${slug}`, {
      jam: {
        title: form.title.trim(),
        tagline: form.tagline.trim() || undefined,
        theme: form.theme.trim() || undefined,
        description: form.description.trim() || undefined,
        rules: form.rules.trim() || undefined,
        prizes: form.prizes.trim() || undefined,
        results_note: form.results_note.trim() || undefined,
        starts_at: toIso(form.starts_at) ?? null,
        submissions_close_at: toIso(form.submissions_close_at) ?? null,
        voting_closes_at: toIso(form.voting_closes_at) ?? null,
        time_zone: form.time_zone,
        judging_mode: form.judging_mode,
        score_scale: form.score_scale,
      },
    })

    data.value = updated
    notice.value = 'Сохранено'
    await refreshNuxtData()
  }
  catch (err) {
    fail(err)
  }
  finally {
    saving.value = false
  }
}

async function uploadBanner(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return

  clearMessages()
  uploading.value = true

  try {
    const body = new FormData()
    body.append('image_file', file)
    const updated = await api.upload<Jam>(`/api/v1/jams/${slug}/banner`, body)
    data.value = updated
    notice.value = 'Баннер обновлён'
    await refreshNuxtData()
  }
  catch (err) {
    fail(err)
  }
  finally {
    uploading.value = false
    input.value = ''
  }
}

async function createCriterion() {
  clearMessages()

  if (!criterionForm.title.trim()) {
    error.value = 'Укажите название критерия.'
    return
  }

  saving.value = true

  try {
    await api.post<JamCriterion>(`/api/v1/jams/${slug}/criteria`, {
      jam_criterion: {
        title: criterionForm.title.trim(),
        description: criterionForm.description.trim() || undefined,
        weight: criterionForm.weight,
      },
    })

    criterionForm.title = ''
    criterionForm.description = ''
    criterionForm.weight = 1
    notice.value = 'Критерий добавлен'
    await refresh()
  }
  catch (err) {
    fail(err)
  }
  finally {
    saving.value = false
  }
}

function startCriterionEdit(criterion: JamCriterion) {
  clearMessages()
  editingCriterionId.value = criterion.id
  criterionDraft.title = criterion.title
  criterionDraft.description = criterion.description ?? ''
  criterionDraft.weight = criterion.weight
}

async function saveCriterion(criterion: JamCriterion) {
  clearMessages()
  saving.value = true

  try {
    await api.patch(`/api/v1/jams/${slug}/criteria/${criterion.id}`, {
      jam_criterion: {
        title: criterionDraft.title.trim(),
        description: criterionDraft.description.trim() || undefined,
        weight: criterionDraft.weight,
      },
    })

    editingCriterionId.value = null
    notice.value = 'Критерий сохранён'
    await refresh()
  }
  catch (err) {
    fail(err)
  }
  finally {
    saving.value = false
  }
}

async function deleteCriterion(criterion: JamCriterion) {
  if (!confirm(`Удалить критерий «${criterion.title}»?`)) return

  clearMessages()

  try {
    await api.del(`/api/v1/jams/${slug}/criteria/${criterion.id}`)
    if (editingCriterionId.value === criterion.id) editingCriterionId.value = null
    notice.value = 'Критерий удалён'
    await refresh()
  }
  catch (err) {
    fail(err)
  }
}

const readyToPublish = computed(() => {
  return !!form.starts_at
    && !!form.submissions_close_at
    && !!form.voting_closes_at
    && criteria.value.length > 0
})

async function publish() {
  clearMessages()
  saving.value = true

  try {
    const updated = await api.post<Jam>(`/api/v1/jams/${slug}/publish`)
    data.value = updated
    notice.value = 'Джем опубликован. Раздел форума создан.'
    await refreshNuxtData()
  }
  catch (err) {
    fail(err)
  }
  finally {
    saving.value = false
  }
}

async function cancelJam() {
  const reason = prompt('Причина отмены джема')
  if (!reason?.trim()) return

  clearMessages()
  saving.value = true

  try {
    const updated = await api.post<Jam>(`/api/v1/jams/${slug}/cancel`, {
      jam: { cancel_reason: reason.trim() },
    })
    data.value = updated
    notice.value = 'Джем отменён'
    await refreshNuxtData()
  }
  catch (err) {
    fail(err)
  }
  finally {
    saving.value = false
  }
}

async function removeJam() {
  if (!confirm('Удалить черновик джема? Это действие необратимо.')) return

  clearMessages()

  try {
    await api.del(`/api/v1/jams/${slug}`)
    await router.push('/dashboard/jams')
  }
  catch (err) {
    fail(err)
  }
}
</script>

<template>
  <div class="container">
    <div v-if="pending" class="empty">
      Загружаем джем…
    </div>

    <div v-else-if="loadError || !jam" class="empty">
      Не удалось загрузить джем.
      <button class="btn btn-ghost btn-sm mt-16" @click="refresh()">
        Повторить
      </button>
    </div>

    <template v-else>
      <div class="page-head">
        <div>
          <div class="row mb-8">
            <h1>{{ jam.title }}</h1>
            <JamPhaseBadge :phase="jam.phase" />
          </div>
          <p class="muted small">
            <code>/jams/{{ jam.slug }}</code>
            <template v-if="jam.forum_section">
              · <NuxtLink :to="`/forum/${jam.forum_section.slug}`">раздел форума</NuxtLink>
            </template>
          </p>
        </div>

        <div class="row">
          <NuxtLink :to="`/jams/${jam.slug}`" class="btn btn-ghost">
            Открыть страницу
          </NuxtLink>
        </div>
      </div>

      <div v-if="error" class="form-error">
        {{ error }}
      </div>
      <div v-if="notice" class="form-success">
        {{ notice }}
      </div>

      <div class="editor-tabs">
        <button class="editor-tab" :class="{ active: tab === 'details' }" @click="tab = 'details'">
          Основное
        </button>
        <button class="editor-tab" :class="{ active: tab === 'criteria' }" @click="tab = 'criteria'">
          Критерии
        </button>
        <button class="editor-tab" :class="{ active: tab === 'publish' }" @click="tab = 'publish'">
          Публикация
        </button>
      </div>

      <section v-if="tab === 'details'">
        <div class="card card-pad" style="max-width: 840px;">
          <div class="jam-banner-editor">
            <div class="jam-banner-preview">
              <img v-if="jam.banner_card_url || jam.banner_url" :src="jam.banner_card_url || jam.banner_url || ''" :alt="jam.title">
              <div v-else class="jam-card-banner-empty" aria-hidden="true">
                {{ jam.title.slice(0, 1) }}
              </div>
            </div>

            <div>
              <label class="label" for="jam-banner">Баннер</label>
              <input
                id="jam-banner"
                type="file"
                accept="image/png,image/jpeg,image/webp"
                :disabled="uploading"
                @change="uploadBanner"
              >
              <span class="hint">PNG, JPEG или WebP до 5 МБ. Пропорции 16:9 выглядят лучше.</span>
            </div>
          </div>

          <div class="field">
            <label class="label" for="jam-title">Название</label>
            <input id="jam-title" v-model="form.title" class="input" maxlength="120">
          </div>

          <div class="field">
            <label class="label" for="jam-tagline">Короткое описание</label>
            <input id="jam-tagline" v-model="form.tagline" class="input" maxlength="200">
          </div>

          <div class="field">
            <label class="label" for="jam-theme">Тема</label>
            <input id="jam-theme" v-model="form.theme" class="input" maxlength="200">
            <span class="hint">До старта тема скрыта от гостей и участников.</span>
          </div>

          <div class="form-grid">
            <div class="field">
              <label class="label" for="jam-starts">Старт</label>
              <input id="jam-starts" v-model="form.starts_at" class="input" type="datetime-local">
            </div>

            <div class="field">
              <label class="label" for="jam-submissions">Приём заявок до</label>
              <input id="jam-submissions" v-model="form.submissions_close_at" class="input" type="datetime-local">
            </div>
          </div>

          <div class="form-grid">
            <div class="field">
              <label class="label" for="jam-voting">Судейство до</label>
              <input id="jam-voting" v-model="form.voting_closes_at" class="input" type="datetime-local">
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

          <div class="form-grid">
            <div class="field">
              <label class="label" for="jam-judging">Кто оценивает</label>
              <select id="jam-judging" v-model="form.judging_mode" class="input">
                <option value="community">Все пользователи</option>
                <option value="participants">Только участники</option>
                <option value="jury">Назначенное жюри</option>
              </select>
            </div>

            <div class="field">
              <label class="label" for="jam-scale">Шкала оценок</label>
              <select id="jam-scale" v-model.number="form.score_scale" class="input">
                <option :value="5">1–5</option>
                <option :value="10">1–10</option>
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
            />
          </div>

          <div class="field">
            <label class="label" for="jam-rules">Правила</label>
            <MarkdownEditor
              id="jam-rules"
              v-model="form.rules"
              :maxlength="50000"
              :rows="10"
            />
          </div>

          <div class="field">
            <label class="label" for="jam-prizes">Призы</label>
            <MarkdownEditor
              id="jam-prizes"
              v-model="form.prizes"
              :maxlength="50000"
              :rows="6"
            />
          </div>

          <div class="field">
            <label class="label" for="jam-results-note">Итоги и победители</label>
            <MarkdownEditor
              id="jam-results-note"
              v-model="form.results_note"
              :maxlength="20000"
              :rows="6"
              placeholder="Победители, номинации и комментарии администратора. Появится на странице после судейства."
            />
          </div>

          <div class="row">
            <button class="btn btn-primary" type="button" :disabled="saving || uploading" @click="save">
              {{ saving ? 'Сохраняем…' : 'Сохранить' }}
            </button>
          </div>
        </div>
      </section>

      <section v-else-if="tab === 'criteria'">
        <div class="card card-pad" style="max-width: 840px;">
          <p class="muted small mb-16">
            Критерии задают, по чему оценивают заявки. Вес 1–3 увеличивает вклад критерия в итоговую оценку.
          </p>

          <div v-if="criteria.length" class="dash-list">
            <template v-for="criterion in criteria" :key="criterion.id">
              <div class="dash-row">
                <div class="dash-info">
                  <div class="row mb-8">
                    <h3>{{ criterion.title }}</h3>
                    <span class="muted small">вес ×{{ criterion.weight }}</span>
                  </div>
                  <p v-if="criterion.description" class="muted small">
                    {{ criterion.description }}
                  </p>
                </div>

                <div class="dash-actions">
                  <button class="btn btn-ghost btn-sm" type="button" @click="startCriterionEdit(criterion)">
                    Изменить
                  </button>
                  <button class="btn btn-danger btn-sm" type="button" @click="deleteCriterion(criterion)">
                    Удалить
                  </button>
                </div>
              </div>

              <form
                v-if="editingCriterionId === criterion.id"
                class="card card-pad"
                @submit.prevent="saveCriterion(criterion)"
              >
                <div class="field">
                  <label class="label" :for="`criterion-title-${criterion.id}`">Название</label>
                  <input :id="`criterion-title-${criterion.id}`" v-model="criterionDraft.title" class="input" maxlength="80">
                </div>
                <div class="field">
                  <label class="label" :for="`criterion-description-${criterion.id}`">Описание</label>
                  <textarea
                    :id="`criterion-description-${criterion.id}`"
                    v-model="criterionDraft.description"
                    class="textarea textarea-sm"
                    maxlength="300"
                    rows="2"
                  />
                </div>
                <div class="field field-narrow">
                  <label class="label" :for="`criterion-weight-${criterion.id}`">Вес</label>
                  <select :id="`criterion-weight-${criterion.id}`" v-model.number="criterionDraft.weight" class="input">
                    <option :value="1">1</option>
                    <option :value="2">2</option>
                    <option :value="3">3</option>
                  </select>
                </div>
                <div class="row">
                  <button class="btn btn-primary" type="submit" :disabled="saving">
                    Сохранить
                  </button>
                  <button class="btn btn-ghost" type="button" @click="editingCriterionId = null">
                    Отмена
                  </button>
                </div>
              </form>
            </template>
          </div>

          <div v-else class="empty">
            Критериев пока нет. Без них джем нельзя опубликовать.
          </div>

          <form class="card card-pad mt-24" @submit.prevent="createCriterion">
            <h2 class="forum-section-form-title">
              Новый критерий
            </h2>

            <div class="field">
              <label class="label" for="new-criterion-title">Название</label>
              <input id="new-criterion-title" v-model="criterionForm.title" class="input" maxlength="80" placeholder="Например: Геймплей">
            </div>

            <div class="field">
              <label class="label" for="new-criterion-description">Описание</label>
              <textarea
                id="new-criterion-description"
                v-model="criterionForm.description"
                class="textarea textarea-sm"
                maxlength="300"
                rows="2"
              />
            </div>

            <div class="field field-narrow">
              <label class="label" for="new-criterion-weight">Вес</label>
              <select id="new-criterion-weight" v-model.number="criterionForm.weight" class="input">
                <option :value="1">1</option>
                <option :value="2">2</option>
                <option :value="3">3</option>
              </select>
            </div>

            <button class="btn btn-primary" type="submit" :disabled="saving || !criterionForm.title.trim()">
              Добавить критерий
            </button>
          </form>
        </div>
      </section>

      <section v-else>
        <div class="card card-pad" style="max-width: 840px;">
          <h2 class="section-title">
            Публикация
          </h2>

          <div v-if="jam.status === 'draft'" class="jam-checklist">
            <div class="jam-checklist-item" :class="{ done: !!form.starts_at }">
              Старт джема — {{ form.starts_at ? 'задан' : 'не задан' }}
            </div>
            <div class="jam-checklist-item" :class="{ done: !!form.submissions_close_at }">
              Конец приёма заявок — {{ form.submissions_close_at ? 'задан' : 'не задан' }}
            </div>
            <div class="jam-checklist-item" :class="{ done: !!form.voting_closes_at }">
              Конец судейства — {{ form.voting_closes_at ? 'задан' : 'не задан' }}
            </div>
            <div class="jam-checklist-item" :class="{ done: criteria.length > 0 }">
              Критерии — {{ criteria.length }}
              {{ plural(criteria.length, 'критерий', 'критерия', 'критериев') }}
            </div>
          </div>

          <p class="muted small">
            При публикации создаётся раздел форума «{{ jam.title }}» внутри категории «Джемы».
            После публикации адрес джема менять нельзя.
          </p>

          <div class="row mt-16">
            <button
              v-if="jam.status === 'draft'"
              class="btn btn-primary"
              type="button"
              :disabled="saving || !readyToPublish"
              @click="publish"
            >
              {{ saving ? 'Публикуем…' : 'Опубликовать джем' }}
            </button>

            <NuxtLink
              v-if="jam.status === 'published'"
              :to="`/jams/${jam.slug}`"
              class="btn btn-primary"
            >
              Джем опубликован
            </NuxtLink>
          </div>

          <div v-if="jam.forum_section" class="mt-24">
            <h3 class="section-title" style="font-size: 15px;">
              Раздел форума
            </h3>
            <p class="muted small">
              Темы джема живут в <NuxtLink :to="`/forum/${jam.forum_section.slug}`">/forum/{{ jam.forum_section.slug }}</NuxtLink>.
            </p>
          </div>

          <div v-if="jam.status !== 'canceled'" class="mt-24">
            <h3 class="section-title" style="font-size: 15px;">
              Опасные действия
            </h3>

            <div class="row">
              <button
                v-if="jam.status === 'published'"
                class="btn btn-danger"
                type="button"
                :disabled="saving"
                @click="cancelJam"
              >
                Отменить джем
              </button>

              <button
                v-if="jam.status === 'draft'"
                class="btn btn-danger"
                type="button"
                :disabled="saving"
                @click="removeJam"
              >
                Удалить черновик
              </button>
            </div>
          </div>
        </div>
      </section>
    </template>
  </div>
</template>
