<script setup lang="ts">
import type { ForumAiAnswer as ForumAiAnswerModel } from '~/types/api'

const props = defineProps<{
  answer: ForumAiAnswerModel
}>()

const ready = computed(() => props.answer.status === 'ready' && !!props.answer.body)
</script>

<template>
  <section v-if="ready" class="forum-ai-answer">
    <details>
      <summary class="forum-ai-summary">
        <span class="forum-ai-caret" aria-hidden="true">▸</span>
        <span class="forum-ai-title">Ответ ИИ</span>
        <span class="forum-ai-badge">ИИ</span>
        <span class="muted small">
          {{ answer.model }} · сгенерирован автоматически
        </span>
      </summary>

      <div class="forum-ai-body">
        <MarkdownBody :source="answer.body || ''" />
        <p class="muted small forum-ai-note">
          Ответ сгенерирован моделью и может ошибаться. Это не мнение администрации.
        </p>
      </div>
    </details>
  </section>

  <section v-else-if="answer.status === 'queued'" class="forum-ai-answer forum-ai-pending">
    <span class="forum-ai-badge">ИИ</span>
    <span class="muted small">ИИ готовит ответ…</span>
  </section>
</template>
