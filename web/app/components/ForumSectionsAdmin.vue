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
const roots = computed(() => sections.value.filter(section => section.parent_id === null))

function childrenOf(section: AdminForumSection): AdminForumSection[] {
  return sections.value.filter(item => item.parent_id === section.id)
}

// Roots first, then their children. The API returns one ordered list; the
// panel renders the same two-level tree as the public forum.
const rows = computed(() => {
  const result: Array<{ section: AdminForumSection, child: boolean }> = []

  for (const root of roots.value) {
    result.push({ section: root, child: false })
    for (const child of childrenOf(root)) {
      result.push({ section: child, child: true })
    }
  }

  return result
})

const groupNames = computed(() => Array.from(new Set(
  roots.value
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
  parent_id: null as number | null,
})

const editingId = ref<number | null>(null)
const editForm = reactive({
  title: '',
  slug: '',
  description: '',
  group_title: '',
  position: 0,
  ai_answers_enabled: true,
  parent_id: null as number | null,
})

function resetForm() {
  form.title = ''
  form.slug = ''
  form.description = ''
  form.group_title = ''
  form.position = ''
  form.parent_id = null
}

function clearMessages() {
  notice.value = ''
  actionError.value = ''
}

function isProtected(section: AdminForumSection): boolean {
  return section.slug === 'projects' || section.slug === 'jams'
}

function slugLocked(section: AdminForumSection): boolean {
  return isProtected(section) || section.topics_count > 0 || section.children_count > 0
}

// A root with children cannot become a child: the forum only has two levels.
function parentLocked(section: AdminForumSection): boolean {
  return isProtected(section) || section.children_count > 0
}

function parentOptions(section?: AdminForumSection): AdminForumSection[] {
  return roots.value.filter(root => root.id !== section?.id)
}

function siblings(section: AdminForumSection): AdminForumSection[] {
  return sections.value.filter(item => item.parent_id === section.parent_id)
}

function canMove(section: AdminForumSection, direction: -1 | 1): boolean {
  const list = siblings(section)
  const index = list.findIndex(item => item.id === section.id)
  const target = index + direction
  return target >= 0 && target < list.length
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
    parent_id: form.parent_id,
    group_title: form.parent_id === null ? form.group_title.trim() : '',
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
  editForm.parent_id = section.parent_id
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

  const parentId = parentLocked(section) ? section.parent_id : editForm.parent_id

  const payload: Record<string, unknown> = {
    title: editForm.title.trim(),
    description: editForm.description.trim(),
    parent_id: parentId,
    group_title: parentId === null ? editForm.group_title.trim() : '',
    position: Number(editForm.position),
    ai_answers_enabled: section.slug === 'projects' ? false : editForm.ai_answers_enabled,
  }

  // The API rejects a slug change for protected sections, for a section with
  // topics and for a section with subsections; the field is disabled there and
  // simply not sent.
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
  const list = siblings(section)
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
  if (isProtected(section)) return
  if (section.children_count > 0) {
    actionError.value = `В разделе «${section.title}» есть подразделы — сначала удалите или перенесите их.`
    return
  }
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
      </NuxtLink>. У форума два уровня: корневой раздел и подраздел. Группа задаёт заголовок
      над корневыми разделами, у подразделов её нет. Позиция — порядок среди соседей
      (меньше — выше). Адрес раздела меняется, только пока в нём нет тем и подразделов.
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
            placeholder="Например: Джемы"
          >
        </div>

        <div class="field">
          <label class="label" for="forum-section-parent">Родительский раздел</label>
          <select id="forum-section-parent" v-model="form.parent_id" class="input">
            <option :value="null">Корневой раздел</option>
            <option v-for="root in parentOptions()" :key="root.id" :value="root.id">
              {{ root.title }}
            </option>
          </select>
        </div>
      </div>

      <div class="form-grid">
        <div class="field">
          <label class="label" for="forum-section-group">Группа</label>
          <input
            id="forum-section-group"
            v-model="form.group_title"
            class="input"
            list="forum-section-groups"
            maxlength="60"
            :disabled="form.parent_id !== null"
            placeholder="Например: Сообщество"
          >
          <datalist id="forum-section-groups">
            <option v-for="group in groupNames" :key="group" :value="group" />
          </datalist>
          <span v-if="form.parent_id !== null" class="muted small">
            У подраздела группа не используется.
          </span>
        </div>

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
      </div>

      <div class="form-grid">
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
      <template v-for="row in rows" :key="row.section.id">
        <div class="dash-row" :class="{ 'forum-section-admin-child': row.child }">
          <div class="dash-info">
            <div class="row mb-8">
              <span v-if="row.child" class="forum-section-child-mark" aria-hidden="true">↳</span>
              <h3>{{ row.section.title }}</h3>
              <code class="muted small">/forum/{{ row.section.slug }}</code>
            </div>

            <p v-if="row.section.description" class="muted small">
              {{ row.section.description }}
            </p>

            <div class="muted small">
              <template v-if="row.child && row.section.parent">
                в разделе «{{ row.section.parent.title }}» ·
              </template>
              {{ row.section.group_title || 'без группы' }} · позиция {{ row.section.position }} ·
              {{ row.section.topics_count }} {{ plural(row.section.topics_count, 'тема', 'темы', 'тем') }} ·
              {{ row.section.posts_count }} {{ plural(row.section.posts_count, 'сообщение', 'сообщения', 'сообщений') }}
              <template v-if="row.section.children_count > 0">
                · {{ row.section.children_count }}
                {{ plural(row.section.children_count, 'подраздел', 'подраздела', 'подразделов') }}
              </template>
              <template v-if="!row.section.ai_answers_enabled">
                · ИИ-ответы выключены
              </template>
            </div>
          </div>

          <div class="dash-actions">
            <button
              class="btn btn-ghost btn-sm"
              type="button"
              title="Выше"
              :disabled="saving || !canMove(row.section, -1)"
              @click="move(row.section, -1)"
            >
              ↑
            </button>
            <button
              class="btn btn-ghost btn-sm"
              type="button"
              title="Ниже"
              :disabled="saving || !canMove(row.section, 1)"
              @click="move(row.section, 1)"
            >
              ↓
            </button>
            <button class="btn btn-ghost btn-sm" type="button" :disabled="saving" @click="startEdit(row.section)">
              Изменить
            </button>
            <button
              class="btn btn-danger btn-sm"
              type="button"
              :disabled="saving || isProtected(row.section) || row.section.topics_count > 0 || row.section.children_count > 0"
              :title="isProtected(row.section)
                ? 'Этот раздел удалить нельзя'
                : (row.section.children_count > 0
                  ? 'Сначала удалите или перенесите подразделы'
                  : (row.section.topics_count > 0 ? 'Удалить можно только пустой раздел' : undefined))"
              @click="remove(row.section)"
            >
              Удалить
            </button>
          </div>
        </div>

        <form
          v-if="editingId === row.section.id"
          class="card card-pad forum-section-form"
          @submit.prevent="saveEdit(row.section)"
        >
          <div class="form-grid">
            <div class="field">
              <label class="label" :for="`forum-section-edit-title-${row.section.id}`">Название</label>
              <input
                :id="`forum-section-edit-title-${row.section.id}`"
                v-model="editForm.title"
                class="input"
                maxlength="80"
              >
            </div>

            <div class="field">
              <label class="label" :for="`forum-section-edit-parent-${row.section.id}`">Родительский раздел</label>
              <select
                :id="`forum-section-edit-parent-${row.section.id}`"
                v-model="editForm.parent_id"
                class="input"
                :disabled="parentLocked(row.section)"
              >
                <option :value="null">Корневой раздел</option>
                <option v-for="root in parentOptions(row.section)" :key="root.id" :value="root.id">
                  {{ root.title }}
                </option>
              </select>
              <span v-if="parentLocked(row.section)" class="muted small">
                {{ isProtected(row.section)
                  ? 'Этот раздел всегда корневой.'
                  : 'У раздела есть подразделы — он должен остаться корневым.' }}
              </span>
            </div>
          </div>

          <div class="form-grid">
            <div class="field">
              <label class="label" :for="`forum-section-edit-group-${row.section.id}`">Группа</label>
              <input
                :id="`forum-section-edit-group-${row.section.id}`"
                v-model="editForm.group_title"
                class="input"
                list="forum-section-groups"
                maxlength="60"
                :disabled="editForm.parent_id !== null"
              >
            </div>

            <div class="field">
              <label class="label" :for="`forum-section-edit-slug-${row.section.id}`">Адрес (slug)</label>
              <input
                :id="`forum-section-edit-slug-${row.section.id}`"
                v-model="editForm.slug"
                class="input"
                maxlength="80"
                :disabled="slugLocked(row.section)"
              >
              <span v-if="slugLocked(row.section)" class="muted small">
                {{ isProtected(row.section)
                  ? 'Адрес этого раздела менять нельзя.'
                  : 'В разделе есть темы или подразделы — адрес менять нельзя.' }}
              </span>
            </div>
          </div>

          <div class="form-grid">
            <div class="field field-narrow">
              <label class="label" :for="`forum-section-edit-position-${row.section.id}`">Позиция</label>
              <input
                :id="`forum-section-edit-position-${row.section.id}`"
                v-model.number="editForm.position"
                class="input"
                type="number"
              >
            </div>

            <div class="field">
              <label class="label" :for="`forum-section-edit-description-${row.section.id}`">Описание</label>
              <textarea
                :id="`forum-section-edit-description-${row.section.id}`"
                v-model="editForm.description"
                class="textarea textarea-sm"
                maxlength="200"
                rows="2"
              />
            </div>
          </div>

          <div class="field">
            <label class="check-row">
              <input
                v-model="editForm.ai_answers_enabled"
                type="checkbox"
                :disabled="row.section.slug === 'projects'"
              >
              <span>
                <span class="check-title">Ответ от ИИ в новых темах</span>
                <span class="hint">
                  {{ row.section.slug === 'projects'
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
