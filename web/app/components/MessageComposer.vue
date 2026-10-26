<script setup lang="ts">
import type { PrivateMessage } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = defineProps<{ username: string }>()

const emit = defineEmits<{
  posted: [message: PrivateMessage]
}>()

const api = useApi()
const body = ref('')
const saving = ref(false)
const error = ref('')

const MAX_CHARS = 5_000

async function submit() {
  if (!body.value.trim()) {
    error.value = 'Добавьте текст сообщения.'
    return
  }

  saving.value = true
  error.value = ''

  try {
    const message = await api.post<PrivateMessage>(`/api/v1/messages/${props.username}`, {
      private_message: { body: body.value.trim() },
    })

    body.value = ''
    emit('posted', message)
  }
  catch (err) {
    error.value = formatApiError(err)
  }
  finally {
    saving.value = false
  }
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
    event.preventDefault()
    submit()
  }
}
</script>

<template>
  <section class="card card-pad chat-composer">
    <div class="row-between mb-8">
      <h2 class="section-title" style="margin-bottom: 0;">
        Сообщение
      </h2>
      <span class="muted small">Markdown, Ctrl+Enter — отправить</span>
    </div>

    <div v-if="error" class="form-error">
      {{ error }}
    </div>

    <div @keydown="onKeydown">
      <MarkdownEditor
        id="private-message"
        v-model="body"
        :rows="5"
        :maxlength="MAX_CHARS"
        placeholder="Напишите сообщение…"
      />
    </div>

    <div class="row mt-16">
      <button class="btn btn-primary" :disabled="saving" type="button" @click="submit">
        {{ saving ? 'Отправляем…' : 'Отправить' }}
      </button>
    </div>
  </section>
</template>
