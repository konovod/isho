<script setup lang="ts">
import type { MarkdownImage } from '~/types/api'
import { formatApiError } from '~/composables/useApi'

const props = withDefaults(defineProps<{
  modelValue: string
  id?: string
  placeholder?: string
  maxlength?: number
  rows?: number
}>(), {
  id: undefined,
  placeholder: '',
  maxlength: 50_000,
  rows: 14,
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const api = useApi()

const textarea = ref<HTMLTextAreaElement | null>(null)
const fileInput = ref<HTMLInputElement | null>(null)
const mode = ref<'write' | 'preview'>('write')
const uploadingCount = ref(0)
const uploadError = ref('')

const uploading = computed(() => uploadingCount.value > 0)

const preview = computed(() => renderMarkdown(props.modelValue))

const IMAGE_TYPES = new Set(['image/png', 'image/jpeg', 'image/webp', 'image/gif'])
const IMAGE_EXTENSIONS = /\.(?:png|jpe?g|webp|gif)$/i

function isSupportedImage(file: File): boolean {
  const type = file.type.toLowerCase()

  if (IMAGE_TYPES.has(type)) return true

  // Some browsers hand over a pasted or dropped file without a MIME type.
  return type === '' && IMAGE_EXTENSIONS.test(file.name)
}

function replaceSelection(next: string, start: number, end: number) {
  emit('update:modelValue', next)

  nextTick(() => {
    const el = textarea.value
    if (!el) return

    el.focus()
    el.setSelectionRange(start, end)
  })
}

function wrap(before: string, after: string, placeholder: string) {
  const el = textarea.value
  if (!el) return

  const start = el.selectionStart
  const end = el.selectionEnd
  const selected = props.modelValue.slice(start, end) || placeholder

  replaceSelection(
    props.modelValue.slice(0, start) + before + selected + after + props.modelValue.slice(end),
    start + before.length,
    start + before.length + selected.length,
  )
}

function prefixLines(prefix: string) {
  const el = textarea.value
  if (!el) return

  const lineStart = props.modelValue.lastIndexOf('\n', el.selectionStart - 1) + 1
  let lineEnd = props.modelValue.indexOf('\n', el.selectionEnd)
  if (lineEnd === -1) lineEnd = props.modelValue.length

  const block = props.modelValue
    .slice(lineStart, lineEnd)
    .split('\n')
    .map(line => prefix + line)
    .join('\n')

  replaceSelection(
    props.modelValue.slice(0, lineStart) + block + props.modelValue.slice(lineEnd),
    lineStart,
    lineStart + block.length,
  )
}

function insertCode() {
  const el = textarea.value
  if (!el) return

  const selected = props.modelValue.slice(el.selectionStart, el.selectionEnd)
  if (selected.includes('\n')) {
    wrap('```\n', '\n```', 'код')
  }
  else {
    wrap('`', '`', 'код')
  }
}

function insertSpoiler() {
  const el = textarea.value
  if (!el) return

  const start = el.selectionStart
  const end = el.selectionEnd
  const selected = props.modelValue.slice(start, end)
  const body = selected || 'Скрытый текст'
  const before = ':::spoiler\n'
  const snippet = `${before}${body}\n:::`

  replaceSelection(
    props.modelValue.slice(0, start) + snippet + props.modelValue.slice(end),
    start + before.length,
    start + before.length + body.length,
  )
}

/* Images */

function pickImage() {
  fileInput.value?.click()
}

function selection(): { start: number, end: number } {
  const el = textarea.value

  return {
    start: el?.selectionStart ?? props.modelValue.length,
    end: el?.selectionEnd ?? props.modelValue.length,
  }
}

function altText(file: File): string {
  const name = file.name.replace(/\.[^.]+$/, '').trim()
  const label = name && !/^(?:image|blob|screenshot)$/i.test(name) ? name : 'Изображение'

  return label.replace(/[[\]\r\n]/g, ' ').slice(0, 100)
}

/**
 * Inserts the uploaded images as ordinary Markdown links at the cursor
 * position captured before the request started.
 */
function insertImages(snippets: string[], start: number, end: number) {
  if (!snippets.length) return

  const value = props.modelValue
  const from = Math.min(Math.max(start, 0), value.length)
  const to = Math.min(Math.max(end, from), value.length)
  const before = value.slice(0, from)
  const after = value.slice(to)
  const leading = before && !before.endsWith('\n') ? '\n' : ''
  const trailing = after && !after.startsWith('\n') ? '\n' : ''
  const snippet = snippets.join('\n')
  const caret = from + leading.length + snippet.length

  replaceSelection(
    before + leading + snippet + trailing + after,
    caret,
    caret,
  )
}

async function uploadImages(files: File[], start: number, end: number) {
  const images = files.filter(isSupportedImage)

  if (!images.length) {
    uploadError.value = 'Можно загрузить только PNG, JPEG, WebP или GIF.'
    return
  }

  uploadError.value = images.length === files.length
    ? ''
    : 'Некоторые файлы пропущены: поддерживаются PNG, JPEG, WebP и GIF.'

  uploadingCount.value += 1
  mode.value = 'write'

  const snippets: string[] = []

  try {
    for (const file of images) {
      const body = new FormData()
      body.append('image_file', file)

      try {
        const image = await api.upload<MarkdownImage>('/api/v1/markdown_images', body)
        snippets.push(`![${altText(file)}](${image.url})`)
      }
      catch (err) {
        uploadError.value = formatApiError(err, `Не удалось загрузить «${file.name}»`)
      }
    }
  }
  finally {
    uploadingCount.value -= 1
  }

  insertImages(snippets, start, end)
}

function clipboardImages(event: ClipboardEvent): File[] {
  const data = event.clipboardData
  if (!data) return []

  const fromItems = Array.from(data.items)
    .filter(item => item.kind === 'file')
    .map(item => item.getAsFile())
    .filter((file): file is File => file !== null && isSupportedImage(file))

  if (fromItems.length) return fromItems

  return Array.from(data.files).filter(isSupportedImage)
}

function onPaste(event: ClipboardEvent) {
  const files = clipboardImages(event)
  if (!files.length) return

  // Keep the browser from also inserting the file name or an <img> tag.
  event.preventDefault()
  const { start, end } = selection()
  uploadImages(files, start, end)
}

function onFileInput(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files ?? [])
  input.value = ''

  if (!files.length) return

  const { start, end } = selection()
  uploadImages(files, start, end)
}

function onDragOver(event: DragEvent) {
  const types = event.dataTransfer?.types

  if (types && Array.from(types).includes('Files')) {
    event.preventDefault()
  }
}

function onDrop(event: DragEvent) {
  const files = Array.from(event.dataTransfer?.files ?? [])
  if (!files.length) return

  if (!files.some(isSupportedImage)) {
    event.preventDefault()
    uploadError.value = 'Можно загрузить только PNG, JPEG, WebP или GIF.'
    return
  }

  event.preventDefault()
  const { start, end } = selection()
  uploadImages(files, start, end)
}
</script>

<template>
  <div class="md-editor" @dragover="onDragOver" @drop="onDrop">
    <div class="md-editor-bar">
      <div class="md-editor-tools">
        <button type="button" class="md-tool" title="Жирный" @click="wrap('**', '**', 'жирный текст')">
          <strong>Ж</strong>
        </button>
        <button type="button" class="md-tool" title="Курсив" @click="wrap('*', '*', 'курсив')">
          <em>К</em>
        </button>
        <button type="button" class="md-tool" title="Заголовок" @click="prefixLines('## ')">
          H
        </button>
        <button type="button" class="md-tool" title="Цитата" @click="prefixLines('> ')">
          ❝
        </button>
        <button type="button" class="md-tool" title="Список" @click="prefixLines('- ')">
          •
        </button>
        <button type="button" class="md-tool" title="Код" @click="insertCode()">
          &lt;/&gt;
        </button>
        <button type="button" class="md-tool" title="Ссылка" @click="wrap('[', '](https://)', 'текст ссылки')">
          ↗
        </button>
        <button type="button" class="md-tool" title="Изображение по ссылке" @click="wrap('![', '](https://)', 'описание')">
          ▣
        </button>
        <button
          type="button"
          class="md-tool"
          title="Загрузить изображение (можно вставить или перетащить)"
          :disabled="uploading"
          @click="pickImage"
        >
          ⬆
        </button>
        <button type="button" class="md-tool" title="Видео Rutube" @click="wrap('![Обзор](', ')\n', 'https://rutube.ru/video/')">
          ▶
        </button>
        <button type="button" class="md-tool" title="Спойлер" @click="insertSpoiler()">
          ▾
        </button>
      </div>

      <div class="md-editor-tabs">
        <button
          type="button"
          class="md-tab"
          :class="{ active: mode === 'write' }"
          @click="mode = 'write'"
        >
          Написать
        </button>
        <button
          type="button"
          class="md-tab"
          :class="{ active: mode === 'preview' }"
          @click="mode = 'preview'"
        >
          Предпросмотр
        </button>
      </div>
    </div>

    <textarea
      v-show="mode === 'write'"
      :id="id"
      ref="textarea"
      class="textarea md-editor-input"
      :placeholder="placeholder"
      :maxlength="maxlength"
      :rows="rows"
      :value="modelValue"
      @input="emit('update:modelValue', ($event.target as HTMLTextAreaElement).value)"
      @paste="onPaste"
    />

    <div v-show="mode === 'preview'" class="md-editor-preview">
      <MarkdownBody v-if="modelValue.trim()" :source="modelValue" />
      <p v-else class="muted small">
        Пока нечего показывать.
      </p>
    </div>

    <div v-if="uploadError" class="md-editor-error" role="alert">
      {{ uploadError }}
    </div>

    <div class="md-editor-foot">
      <span class="hint">
        <template v-if="uploading">
          Загружаем изображение…
        </template>
        <template v-else>
          Markdown, картинку можно вставить из буфера, перетащить или загрузить файлом.
        </template>
      </span>
      <span class="hint">{{ modelValue.length }} / {{ maxlength }}</span>
    </div>

    <details class="md-help">
      <summary>Синтаксис</summary>
      <div class="md-help-body">
        <ul>
          <li><code>![описание](https://example.com/a.png)</code> — изображение по ссылке</li>
          <li>Картинку можно вставить из буфера обмена, перетащить в поле или загрузить кнопкой ⬆ — PNG, JPEG, WebP, GIF до 10 МБ</li>
          <li><code>![Обзор](https://rutube.ru/video/&lt;id&gt;/)</code> — видео Rutube, можно вставить только id</li>
          <li><code>:::spoiler Заголовок</code> … <code>:::</code> — спойлер, заголовок необязателен</li>
          <li><code>```js</code> … <code>```</code> — код с подсветкой: js, ts, vue, html, css, json, bash, powershell, python, ruby, crystal, go, rust, c#, sql и другие</li>
        </ul>
      </div>
    </details>

    <input
      ref="fileInput"
      type="file"
      accept="image/png,image/jpeg,image/webp,image/gif"
      multiple
      hidden
      @change="onFileInput"
    >
  </div>
</template>
