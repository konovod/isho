<script setup lang="ts">
import type { AdminForumSection } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const api = useApi()
const { plural } = useFormat()

const {
  data,
  pending,
  error: loadError,
  refresh,
} = await useAsyncData(
  'admin-forum-sections',
  () => api.get<{ items: AdminForumSection[] }>('/api/v1/admin/forum/sections'),
)

const sections = computed(() => data.value?.items ?? [])

const groupNames = computed(() => Array.from(new Set(
  sections.value
    .map(section => section.group_title)
    .filter((title): title is string => !!title),
)))

const notice = ref('')
const actionError = ref('')
const saving = ref(false)

const form = reactive({
  title: '',
  slug: '',
  description: '',
  group_title: '',
  position: '',
})

const editingId = ref<number | null>(null)
const editForm = reactive({
  title: '',
  slug: '',
  description: '',
  group_title: '',
  position: 0,
  ai_answers_enabled: true,
})

function resetForm() {
  form.title = ''
  form.slug = ''
  form.description = ''
  form.group_title = ''
  form.position = ''
}

function clearMessages() {
  notice.value = ''
  actionError.value = ''
}

function slugLocked(section: AdminForumSection): boolean {
  return section.slug === 'projects' || section.topics_count > 0
}

async function createSection() {
  clearMessages()

  if (!form.title.trim()) {
    actionError.value = 'Укажите название раздела.'
    return
  }

  const payload: Record<string, unknown> = {
    title: form.title.trim(),
    description: form.description.trim(),
    group_title: form.group_title.trim(),
  }

  if (form.slug.trim()) payload.slug = form.slug.trim()

  const positionText = form.position.trim()
  if (positionText) {
    const position = Number(positionText)
    if (!Number.isFinite(position)) {
      actionError.value = 'Позиция должна быть числом.'
      return
    }
    payload.position = position
  }

  saving.value = true

  try {
    const created = await api.post<AdminForumSection>('/api/v1/admin/forum/sections', {
      forum_section: payload,
    })

    resetForm()
    notice.value = `Раздел «${created.title}» создан: /forum/${created.slug}`
    await refresh()
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

function startEdit(section: AdminForumSection) {
  clearMessages()
  editingId.value = section.id
  editForm.title = section.title
  editForm.slug = section.slug
  editForm.description = section.description ?? ''
  editForm.group_title = section.group_title ?? ''
  editForm.position = section.position
  editForm.ai_answers_enabled = section.ai_answers_enabled
}

function cancelEdit() {
  editingId.value = null
}

async function saveEdit(section: AdminForumSection) {
  clearMessages()

  if (!editForm.title.trim()) {
    actionError.value = 'Укажите название раздела.'
    return
  }

  const payload: Record<string, unknown> = {
    title: editForm.title.trim(),
    description: editForm.description.trim(),
    group_title: editForm.group_title.trim(),
    position: Number(editForm.position),
    ai_answers_enabled: section.slug === 'projects' ? false : editForm.ai_answers_enabled,
  }

  // The API rejects a slug change for "projects" and for a section with
  // topics; the field is disabled there and simply not sent.
  if (!slugLocked(section)) payload.slug = editForm.slug.trim()

  saving.value = true

  try {
    const updated = await api.patch<AdminForumSection>(`/api/v1/admin/forum/sections/${section.id}`, {
      forum_section: payload,
    })

    editingId.value = null
    notice.value = `Раздел «${updated.title}» сохранён`
    await refresh()
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

async function move(section: AdminForumSection, direction: -1 | 1) {
  const list = sections.value
  const index = list.findIndex(item => item.id === section.id)
  const neighbor = list[index + direction]
  if (!neighbor) return

  clearMessages()
  saving.value = true

  try {
    if (section.position === neighbor.position) {
      // Positions may repeat (a new section without one gets the last + 10,
      // but older data can be flat). Nudging by one is enough to reorder.
      await api.patch(`/api/v1/admin/forum/sections/${section.id}`, {
        forum_section: { position: neighbor.position + direction },
      })
    }
    else {
      await Promise.all([
        api.patch(`/api/v1/admin/forum/sections/${section.id}`, {
          forum_section: { position: neighbor.position },
        }),
        api.patch(`/api/v1/admin/forum/sections/${neighbor.id}`, {
          forum_section: { position: section.position },
        }),
      ])
    }

    await refresh()
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

async function remove(section: AdminForumSection) {
  if (section.slug === 'projects') return
  if (section.topics_count > 0) {
    actionError.value = `В разделе «${section.title}» есть темы — удалить можно только пустой раздел.`
    return
  }
  if (!confirm(`Удалить раздел «${section.title}»? Это действие необратимо.`)) return

  clearMessages()
  saving.value = true

  try {
    await api.del(`/api/v1/admin/forum/sections/${section.id}`)
    if (editingId.value === section.id) editingId.value = null
    notice.value = `Раздел «${section.title}» удалён`
    await refresh()
  }
  catch (err) {
    actionError.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="forum-sections-admin">
    <p class="muted small mb-16">
      Раздел — это карточка на <NuxtLink to="/forum">
        странице форума
      </NuxtLink>. Группа задаёт заголовок над карточками, позиция — порядок (меньше — выше).
      Адрес раздела меняется, только пока в нём нет тем.
    </p>

    <div v-if="actionError" class="form-error">
      {{ actionError }}
    </div>
    <div v-if="notice" class="form-success">
      {{ notice }}
    </div>

    <form class="card card-pad forum-section-form" @submit.prevent="createSection">
      <h2 class="forum-section-form-title">
        Новый раздел
      </h2>

      <div class="form-grid">
        <div class="field">
          <label class="label" for="forum-section-title">Название</label>
          <input
            id="forum-section-title"
            v-model="form.title"
            class="input"
            maxlength="80"
            placeholder="Например: Конкурсы и соревнования"
          >
        </div>

        <div class="field">
          <label class="label" for="forum-section-group">Группа</label>
          <input
            id="forum-section-group"
            v-model="form.group_title"
            class="input"
            list="forum-section-groups"
            maxlength="60"
            placeholder="Например: Сообщество"
          >
          <datalist id="forum-section-groups">
            <option v-for="group in groupNames" :key="group" :value="group" />
          </datalist>
        </div>
      </div>

      <div class="form-grid">
        <div class="field">
          <label class="label" for="forum-section-slug">Адрес (slug)</label>
          <input
            id="forum-section-slug"
            v-model="form.slug"
            class="input"
            maxlength="80"
            placeholder="Пусто — из названия"
          >
        </div>

        <div class="field field-narrow">
          <label class="label" for="forum-section-position">Позиция</label>
          <input
            id="forum-section-position"
            v-model="form.position"
            class="input"
            type="number"
            placeholder="В конец"
          >
        </div>
      </div>

      <div class="field">
        <label class="label" for="forum-section-description">Описание</label>
        <textarea
          id="forum-section-description"
          v-model="form.description"
          class="textarea textarea-sm"
          maxlength="200"
          rows="2"
          placeholder="О чём раздел — видно на странице форума"
        />
      </div>

      <div class="row">
        <button class="btn btn-primary" type="submit" :disabled="saving || !form.title.trim()">
          {{ saving ? 'Создаём…' : 'Создать раздел' }}
        </button>
        <button class="btn btn-ghost" type="button" :disabled="saving" @click="resetForm">
          Очистить
        </button>
      </div>
    </form>

    <div v-if="pending" class="empty">
      Загружаем разделы…
    </div>

    <div v-else-if="loadError" class="empty">
      Не удалось загрузить разделы.
      <button class="btn btn-ghost btn-sm mt-16" @click="refresh()">
        Повторить
      </button>
    </div>

    <div v-else-if="!sections.length" class="empty">
      Разделов ещё нет — создайте первый.
    </div>

    <div v-else class="dash-list">
      <template v-for="(section, index) in sections" :key="section.id">
        <div class="dash-row">
          <div class="dash-info">
            <div class="row mb-8">
              <h3>{{ section.title }}</h3>
              <code class="muted small">/forum/{{ section.slug }}</code>
            </div>

            <p v-if="section.description" class="muted small">
              {{ section.description }}
            </p>

            <div class="muted small">
              {{ section.group_title || 'без группы' }} · позиция {{ section.position }} ·
              {{ section.topics_count }} {{ plural(section.topics_count, 'тема', 'темы', 'тем') }} ·
              {{ section.posts_count }} {{ plural(section.posts_count, 'сообщение', 'сообщения', 'сообщений') }}
              <template v-if="!section.ai_answers_enabled">
                · ИИ-ответы выключены
              </template>
            </div>
          </div>

          <div class="dash-actions">
            <button
              class="btn btn-ghost btn-sm"
              type="button"
              title="Выше"
              :disabled="saving || index === 0"
              @click="move(section, -1)"
            >
              ↑
            </button>
            <button
              class="btn btn-ghost btn-sm"
              type="button"
              title="Ниже"
              :disabled="saving || index === sections.length - 1"
              @click="move(section, 1)"
            >
              ↓
            </button>
            <button class="btn btn-ghost btn-sm" type="button" :disabled="saving" @click="startEdit(section)">
              Изменить
            </button>
            <button
              class="btn btn-danger btn-sm"
              type="button"
              :disabled="saving || section.slug === 'projects' || section.topics_count > 0"
              :title="section.slug === 'projects'
                ? 'Раздел обсуждений проектов удалить нельзя'
                : (section.topics_count > 0 ? 'Удалить можно только пустой раздел' : undefined)"
              @click="remove(section)"
            >
              Удалить
            </button>
          </div>
        </div>

        <form
          v-if="editingId === section.id"
          class="card card-pad forum-section-form"
          @submit.prevent="saveEdit(section)"
        >
          <div class="form-grid">
            <div class="field">
              <label class="label" :for="`forum-section-edit-title-${section.id}`">Название</label>
              <input
                :id="`forum-section-edit-title-${section.id}`"
                v-model="editForm.title"
                class="input"
                maxlength="80"
              >
            </div>

            <div class="field">
              <label class="label" :for="`forum-section-edit-group-${section.id}`">Группа</label>
              <input
                :id="`forum-section-edit-group-${section.id}`"
                v-model="editForm.group_title"
                class="input"
                list="forum-section-groups"
                maxlength="60"
              >
            </div>
          </div>

          <div class="form-grid">
            <div class="field">
              <label class="label" :for="`forum-section-edit-slug-${section.id}`">Адрес (slug)</label>
              <input
                :id="`forum-section-edit-slug-${section.id}`"
                v-model="editForm.slug"
                class="input"
                maxlength="80"
                :disabled="slugLocked(section)"
              >
              <span v-if="slugLocked(section)" class="muted small">
                {{ section.slug === 'projects'
                  ? 'Адрес раздела обсуждений проектов менять нельзя.'
                  : 'В разделе есть темы — адрес менять нельзя.' }}
              </span>
            </div>

            <div class="field field-narrow">
              <label class="label" :for="`forum-section-edit-position-${section.id}`">Позиция</label>
              <input
                :id="`forum-section-edit-position-${section.id}`"
                v-model.number="editForm.position"
                class="input"
                type="number"
              >
            </div>
          </div>

          <div class="field">
            <label class="label" :for="`forum-section-edit-description-${section.id}`">Описание</label>
            <textarea
              :id="`forum-section-edit-description-${section.id}`"
              v-model="editForm.description"
              class="textarea textarea-sm"
              maxlength="200"
              rows="2"
            />
          </div>

          <div class="field">
            <label class="check-row">
              <input
                v-model="editForm.ai_answers_enabled"
                type="checkbox"
                :disabled="section.slug === 'projects'"
              >
              <span>
                <span class="check-title">Ответ от ИИ в новых темах</span>
                <span class="hint">
                  {{ section.slug === 'projects'
                    ? 'В обсуждениях проектов ИИ не отвечает.'
                    : 'Автор темы может попросить модель ответить первым сообщением под спойлером.' }}
                </span>
              </span>
            </label>
          </div>

          <div class="row">
            <button class="btn btn-primary" type="submit" :disabled="saving || !editForm.title.trim()">
              {{ saving ? 'Сохраняем…' : 'Сохранить' }}
            </button>
            <button class="btn btn-ghost" type="button" :disabled="saving" @click="cancelEdit">
              Отмена
            </button>
          </div>
        </form>
      </template>
    </div>
  </div>
</template>
