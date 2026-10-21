<script setup lang="ts">
import type { ProjectDetail } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = defineProps<{ slug: string }>()
const emit = defineEmits<{ done: [project: ProjectDetail] }>()

const api = useApi()
const fieldId = computed(() => `moderation-reason-${props.slug}`)
const open = ref(false)
const reason = ref('')
const error = ref('')
const saving = ref(false)

function cancel() {
  open.value = false
  reason.value = ''
  error.value = ''
}

async function submit() {
  const note = reason.value.trim()

  if (!note) {
    error.value = 'Укажите причину.'
    return
  }

  saving.value = true
  error.value = ''

  try {
    const updated = await api.post<ProjectDetail>(`/api/v1/admin/projects/${props.slug}/unpublish`, {
      project: { moderation_note: note },
    })

    cancel()
    emit('done', updated)
  }
  catch (err) {
    error.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="moderation-unpublish">
    <button v-if="!open" class="btn btn-danger btn-sm" type="button" @click="open = true">
      Снять с публикации
    </button>

    <form v-else @submit.prevent="submit">
      <div class="field">
        <label class="label" :for="fieldId">Причина (увидит автор)</label>
        <textarea
          :id="fieldId"
          v-model="reason"
          class="textarea textarea-sm"
          maxlength="500"
          rows="3"
          placeholder="Например: проект нарушает правила каталога"
        />
      </div>

      <div class="row">
        <button class="btn btn-danger" type="submit" :disabled="saving || !reason.trim()">
          {{ saving ? 'Снимаем…' : 'Снять с публикации' }}
        </button>
        <button class="btn btn-ghost" type="button" :disabled="saving" @click="cancel">
          Отмена
        </button>
      </div>
    </form>

    <div v-if="error" class="form-error mt-16">
      {{ error }}
    </div>
  </div>
</template>
