<script setup lang="ts">
import type { ProjectDetail } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

definePageMeta({ middleware: 'auth' })

const api = useApi()
const router = useRouter()

const form = reactive({
  title: '',
  tagline: '',
  description: '',
  kind: 'game',
})

const error = ref('')
const pending = ref(false)

async function submit() {
  error.value = ''
  pending.value = true

  try {
    const project = await api.post<ProjectDetail>('/api/v1/projects', {
      project: {
        title: form.title.trim(),
        tagline: form.tagline.trim() || undefined,
        description: form.description.trim() || undefined,
        kind: form.kind,
      },
    })

    await router.push(`/dashboard/projects/${project.slug}/edit`)
  }
  catch (err) {
    error.value = formatApiError(err, 'Не удалось создать проект')
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
        <h1>Новый проект</h1>
        <p>Название и обложку можно изменить позже.</p>
      </div>
    </div>

    <div class="card card-pad" style="max-width: 640px;">
      <div v-if="error" class="form-error">
        {{ error }}
      </div>

      <form @submit.prevent="submit">
        <div class="field">
          <label class="label" for="title">Название</label>
          <input id="title" v-model="form.title" class="input" maxlength="120" required>
        </div>

        <div class="field">
          <label class="label" for="tagline">Короткое описание</label>
          <input id="tagline" v-model="form.tagline" class="input" maxlength="160" placeholder="Одна строка о проекте">
        </div>

        <div class="field">
          <label class="label" for="kind">Тип</label>
          <select id="kind" v-model="form.kind" class="select">
            <option value="game">Игра</option>
            <option value="tool">Инструмент</option>
            <option value="asset">Ассет</option>
          </select>
        </div>

        <div class="field">
          <label class="label" for="description">Описание</label>
          <textarea id="description" v-model="form.description" class="textarea" maxlength="20000" placeholder="Что это, для кого и как играть" />
        </div>

        <div class="row">
          <button class="btn btn-primary" type="submit" :disabled="pending">
            {{ pending ? 'Создаём…' : 'Создать черновик' }}
          </button>
          <NuxtLink to="/dashboard" class="btn btn-ghost">
            Отмена
          </NuxtLink>
        </div>
      </form>
    </div>
  </div>
</template>
