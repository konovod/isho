<script setup lang="ts">
import type { Tag, TagDraft } from '~/types/api'

const MAX_NAME_LENGTH = 40

const props = withDefaults(defineProps<{
  modelValue: TagDraft[]
  suggestions: Tag[]
  max?: number
}>(), {
  max: 8,
})

const emit = defineEmits<{
  'update:modelValue': [value: TagDraft[]]
}>()

const rootEl = ref<HTMLElement | null>(null)
const inputEl = ref<HTMLInputElement | null>(null)
const query = ref('')
const open = ref(false)
const activeIndex = ref(-1)

const trimmedQuery = computed(() => query.value.trim().replace(/\s+/g, ' '))

const canAddMore = computed(() => props.modelValue.length < props.max)

const matches = computed(() => {
  const taken = new Set(props.modelValue.map(tag => tag.name.toLowerCase()))
  const needle = trimmedQuery.value.toLowerCase()

  return props.suggestions
    .filter(tag => !taken.has(tag.name.toLowerCase()))
    .filter(tag => !needle || tag.name.toLowerCase().includes(needle) || tag.slug.includes(needle))
    .slice(0, 6)
})

const exactMatch = computed(() => {
  const needle = trimmedQuery.value.toLowerCase()
  if (!needle) return undefined

  return props.suggestions.find(tag => tag.name.toLowerCase() === needle || tag.slug === needle)
})

const canCreate = computed(() =>
  canAddMore.value && trimmedQuery.value.length > 0 && !exactMatch.value,
)

const optionCount = computed(() => matches.value.length + (canCreate.value ? 1 : 0))

const activeOptionId = computed(() =>
  activeIndex.value >= 0 ? `tag-option-${activeIndex.value}` : undefined,
)

function addTag(name: string) {
  const clean = name.trim().replace(/\s+/g, ' ').slice(0, MAX_NAME_LENGTH).trim()
  if (!clean || !canAddMore.value) return

  const needle = clean.toLowerCase()
  if (props.modelValue.some(tag => tag.name.toLowerCase() === needle)) {
    resetQuery()
    return
  }

  const existing = props.suggestions.find(tag =>
    tag.name.toLowerCase() === needle || tag.slug === needle,
  )

  emit('update:modelValue', [
    ...props.modelValue,
    existing ? { name: existing.name, slug: existing.slug } : { name: clean, slug: null },
  ])

  resetQuery()
}

function removeTag(index: number) {
  emit('update:modelValue', props.modelValue.filter((_, current) => current !== index))
}

function resetQuery() {
  query.value = ''
  open.value = false
  activeIndex.value = -1
  inputEl.value?.focus()
}

function onInput() {
  activeIndex.value = -1
  open.value = true
}

function onKeydown(event: KeyboardEvent) {
  const rows = optionCount.value

  switch (event.key) {
    case 'Enter': {
      event.preventDefault()
      if (!trimmedQuery.value) return

      const highlighted = activeIndex.value >= 0 ? matches.value[activeIndex.value] : undefined
      if (highlighted) {
        addTag(highlighted.name)
      }
      else if (exactMatch.value) {
        addTag(exactMatch.value.name)
      }
      else if (canCreate.value) {
        addTag(trimmedQuery.value)
      }
      break
    }
    case 'ArrowDown':
      if (!rows) return
      event.preventDefault()
      activeIndex.value = activeIndex.value >= rows - 1 ? 0 : activeIndex.value + 1
      open.value = true
      break
    case 'ArrowUp':
      if (!rows) return
      event.preventDefault()
      activeIndex.value = activeIndex.value <= 0 ? rows - 1 : activeIndex.value - 1
      open.value = true
      break
    case 'Backspace':
      if (!query.value && props.modelValue.length) {
        removeTag(props.modelValue.length - 1)
      }
      break
    case 'Escape':
      open.value = false
      break
    case ',':
      event.preventDefault()
      addTag(trimmedQuery.value)
      break
  }
}

function onFocusOut(event: FocusEvent) {
  const next = event.relatedTarget as Node | null
  if (next && rootEl.value?.contains(next)) return
  open.value = false
}
</script>

<template>
  <div ref="rootEl" class="tag-input" @focusout="onFocusOut">
    <div class="tag-input-field" @click="inputEl?.focus()">
      <span
        v-for="(tag, index) in modelValue"
        :key="`${tag.name}-${index}`"
        class="tag-chip"
        :class="{ 'tag-chip-new': tag.slug === null }"
      >
        {{ tag.name }}
        <button
          type="button"
          class="tag-chip-remove"
          :aria-label="`Убрать тег ${tag.name}`"
          @click.stop="removeTag(index)"
        >
          ×
        </button>
      </span>

      <input
        ref="inputEl"
        v-model="query"
        class="tag-input-text"
        type="text"
        :maxlength="MAX_NAME_LENGTH"
        :disabled="!canAddMore"
        :placeholder="canAddMore ? 'Начните вводить название…' : 'Максимум тегов'"
        role="combobox"
        aria-autocomplete="list"
        :aria-expanded="open && optionCount > 0"
        aria-controls="tag-suggestions"
        :aria-activedescendant="activeOptionId"
        autocomplete="off"
        @input="onInput"
        @focus="open = true"
        @keydown="onKeydown"
      >
    </div>

    <div v-if="open && optionCount" id="tag-suggestions" class="tag-suggest" role="listbox">
      <button
        v-for="(tag, index) in matches"
        :id="`tag-option-${index}`"
        :key="tag.id"
        type="button"
        class="tag-suggest-item"
        :class="{ active: activeIndex === index }"
        role="option"
        :aria-selected="activeIndex === index"
        @mousedown.prevent="addTag(tag.name)"
        @mouseenter="activeIndex = index"
      >
        <span>{{ tag.name }}</span>
        <span class="tag-suggest-slug">{{ tag.slug }}</span>
      </button>

      <button
        v-if="canCreate"
        :id="`tag-option-${matches.length}`"
        type="button"
        class="tag-suggest-item tag-suggest-create"
        :class="{ active: activeIndex === matches.length }"
        role="option"
        :aria-selected="activeIndex === matches.length"
        @mousedown.prevent="addTag(trimmedQuery)"
        @mouseenter="activeIndex = matches.length"
      >
        <span>Создать тег «{{ trimmedQuery }}»</span>
        <span class="tag-suggest-hint">Enter</span>
      </button>
    </div>

    <span class="hint tag-input-hint">
      {{ modelValue.length }} / {{ max }}.
      Введите название и нажмите Enter — новый тег сохранится вместе с проектом.
    </span>
  </div>
</template>
