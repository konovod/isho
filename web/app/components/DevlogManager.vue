<script setup lang="ts">
import type { Devlog } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = defineProps<{
  devlogs: Devlog[]
  projectSlug: string
}>()

const emit = defineEmits<{
  'update:devlogs': [value: Devlog[]]
  notice: [value: string]
  error: [value: string]
}>()

const api = useApi()
const { date, plural } = useFormat()

const activeId = ref<number | 'new' | null>(null)
const form = reactive({ title: '', body: '' })
const saving = ref(false)
const localError = ref('')

function startNew() {
  activeId.value = 'new'
  form.title = ''
  form.body = ''
  localError.value = ''
}

function startEdit(devlog: Devlog) {
  activeId.value = devlog.id
  form.title = devlog.title
  form.body = devlog.body
  localError.value = ''
}

function cancel() {
  activeId.value = null
  localError.value = ''
}

async function save() {
  if (!form.title.trim()) {
    localError.value = 'Укажите название записи.'
    return
  }

  if (!form.body.trim()) {
    localError.value = 'Добавьте текст записи.'
    return
  }

  saving.value = true
  localError.value = ''

  try {
    if (activeId.value === 'new') {
      const devlog = await api.post<Devlog>(`/api/v1/projects/${props.projectSlug}/devlogs`, {
        devlog: { title: form.title.trim(), body: form.body.trim() },
      })

      emit('update:devlogs', [devlog, ...props.devlogs])
      emit('notice', 'Запись добавлена')
    }
    else if (typeof activeId.value === 'number') {
      const id = activeId.value
      const devlog = await api.patch<Devlog>(`/api/v1/projects/${props.projectSlug}/devlogs/${id}`, {
        devlog: { title: form.title.trim(), body: form.body.trim() },
      })

      emit('update:devlogs', props.devlogs.map(item => (item.id === id ? devlog : item)))
      emit('notice', 'Запись сохранена')
    }

    activeId.value = null
  }
  catch (err) {
    localError.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

async function remove(devlog: Devlog) {
  if (!confirm(`Удалить запись «${devlog.title}»?`)) return

  try {
    await api.del(`/api/v1/projects/${props.projectSlug}/devlogs/${devlog.id}`)
    emit('update:devlogs', props.devlogs.filter(item => item.id !== devlog.id))
    if (activeId.value === devlog.id) activeId.value = null
    emit('notice', 'Запись удалена')
  }
  catch (err) {
    emit('error', formatApiError(err))
  }
}
</script>

<template>
  <div>
    <div class="row-between mb-16">
      <div>
        <h2 class="section-title" style="margin-bottom: 4px;">
          Девлоги
        </h2>
        <p class="muted small">
          {{ devlogs.length }}
          {{ plural(devlogs.length, 'запись', 'записи', 'записей') }}.
          Короткие показываются на странице проекта целиком, длинные — со ссылкой на отдельную страницу.
        </p>
      </div>

      <button v-if="activeId === null" class="btn btn-primary btn-sm" @click="startNew">
        + Новая запись
      </button>
    </div>

    <div v-if="localError" class="form-error">
      {{ localError }}
    </div>

    <div v-if="activeId !== null" class="card card-pad mb-24 devlog-form">
      <div class="field">
        <label class="label" for="devlog-title">Название</label>
        <input id="devlog-title" v-model="form.title" class="input" maxlength="120" placeholder="Дневник разработки №1">
      </div>

      <div class="field">
        <label class="label" for="devlog-body">Текст</label>
        <MarkdownEditor
          id="devlog-body"
          v-model="form.body"
          :rows="16"
          placeholder="Что нового, что не получилось, что дальше…"
        />
      </div>

      <div class="row">
        <button class="btn btn-primary" :disabled="saving" @click="save">
          {{ saving ? 'Сохраняем…' : 'Сохранить' }}
        </button>
        <button class="btn btn-ghost" :disabled="saving" @click="cancel">
          Отмена
        </button>
      </div>
    </div>

    <div v-if="!devlogs.length && activeId === null" class="empty">
      Пока нет записей. Расскажите, как идёт работа над проектом.
    </div>

    <div v-else class="devlog-list">
      <article v-for="devlog in devlogs" :key="devlog.id" class="card card-pad devlog-item">
        <div class="row-between mb-8">
          <h3 class="devlog-item-title">
            {{ devlog.title }}
          </h3>
          <span class="muted small">{{ date(devlog.created_at) }}</span>
        </div>

        <p class="muted small devlog-item-preview">
          {{ devlogPreview(devlog.body) || 'Пустая запись' }}
        </p>

        <div class="row mt-16">
          <span v-if="isLongDevlog(devlog.body)" class="badge badge-external">длинная</span>
          <NuxtLink
            v-if="isLongDevlog(devlog.body)"
            :to="`/p/${projectSlug}/devlog/${devlog.slug}`"
            class="btn btn-ghost btn-sm"
          >
            Открыть
          </NuxtLink>
          <button class="btn btn-ghost btn-sm" @click="startEdit(devlog)">
            Изменить
          </button>
          <button class="btn btn-danger btn-sm" @click="remove(devlog)">
            Удалить
          </button>
        </div>
      </article>
    </div>
  </div>
</template>
