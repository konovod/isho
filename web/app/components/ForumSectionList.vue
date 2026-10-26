<script setup lang="ts">
import type { ForumSection } from '~/types/api'

const props = defineProps<{
  sections: ForumSection[]
}>()

const roots = computed(() => props.sections.filter(section => section.parent_id === null))

const childrenByParent = computed(() => {
  const map = new Map<number, ForumSection[]>()

  for (const section of props.sections) {
    if (section.parent_id === null) continue

    const list = map.get(section.parent_id) ?? []
    list.push(section)
    map.set(section.parent_id, list)
  }

  return map
})

const groups = computed(() => {
  const map = new Map<string, ForumSection[]>()

  for (const section of roots.value) {
    const key = section.group_title || 'Разделы'
    const list = map.get(key) ?? []
    list.push(section)
    map.set(key, list)
  }

  return Array.from(map, ([title, items]) => ({ title, items }))
})

function childrenOf(section: ForumSection): ForumSection[] {
  return childrenByParent.value.get(section.id) ?? []
}
</script>

<template>
  <div class="forum-sections">
    <section v-for="group in groups" :key="group.title" class="forum-group">
      <h2 class="forum-group-title">{{ group.title }}</h2>

      <div class="forum-group-card">
        <template v-for="section in group.items" :key="section.id">
          <div class="forum-subcat">
            <ForumSectionRow :section="section" />
            <NuxtLink
              v-if="section.slug !== 'projects'"
              :to="`/forum/${section.slug}/new`"
              class="forum-subcat-plus"
              :title="`Новая тема в разделе «${section.title}»`"
              :aria-label="`Новая тема в разделе «${section.title}»`"
            >
              +
            </NuxtLink>
          </div>

          <div v-if="childrenOf(section).length" class="forum-section-children">
            <ForumSectionRow
              v-for="child in childrenOf(section)"
              :key="child.id"
              :section="child"
              child
            />
          </div>
        </template>
      </div>
    </section>
  </div>
</template>
