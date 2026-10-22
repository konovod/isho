<script setup lang="ts">
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

const textarea = ref<HTMLTextAreaElement | null>(null)
const mode = ref<'write' | 'preview'>('write')

const preview = computed(() => renderMarkdown(props.modelValue))

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
</script>

<template>
  <div class="md-editor">
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
        <button type="button" class="md-tool" title="Изображение" @click="wrap('![', '](https://)', 'описание')">
          ▣
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
    />

    <div v-show="mode === 'preview'" class="md-editor-preview">
      <MarkdownBody v-if="modelValue.trim()" :source="modelValue" />
      <p v-else class="muted small">
        Пока нечего показывать.
      </p>
    </div>

    <div class="md-editor-foot">
      <span class="hint">
        Markdown: заголовки, списки, ссылки, изображения, видео, спойлеры, код.
      </span>
      <span class="hint">{{ modelValue.length }} / {{ maxlength }}</span>
    </div>

    <details class="md-help">
      <summary>Синтаксис</summary>
      <div class="md-help-body">
        <ul>
          <li><code>![описание](https://example.com/a.png)</code> — изображение</li>
          <li><code>![Обзор](https://rutube.ru/video/&lt;id&gt;/)</code> — видео Rutube, можно вставить только id</li>
          <li><code>:::spoiler Заголовок</code> … <code>:::</code> — спойлер, заголовок необязателен</li>
          <li><code>```js</code> … <code>```</code> — код с подсветкой: js, ts, vue, html, css, json, bash, powershell, python, ruby, crystal, go, rust, c#, sql и другие</li>
        </ul>
      </div>
    </details>
  </div>
</template>
