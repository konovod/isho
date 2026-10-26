import type { ProjectDevStatus, ProjectGenre, ProjectKind } from '~/types/api'

export interface ProjectOption<T extends string> {
  value: T
  label: string
}

export const PROJECT_KINDS: ProjectOption<ProjectKind>[] = [
  { value: 'game', label: 'Игра' },
  { value: 'tool', label: 'Инструмент' },
  { value: 'asset', label: 'Ассет' },
]

export const PROJECT_DEV_STATUSES: ProjectOption<ProjectDevStatus>[] = [
  { value: 'prototype', label: 'Прототип' },
  { value: 'alpha', label: 'Альфа' },
  { value: 'beta', label: 'Бета' },
  { value: 'active', label: 'Активный' },
  { value: 'completed', label: 'Завершён' },
  { value: 'contest', label: 'Конкурсный' },
  { value: 'abandoned', label: 'Заброшен' },
]

/** Only games get a genre; the server clears it for tools and assets. */
export const PROJECT_GENRES: ProjectOption<ProjectGenre>[] = [
  { value: 'action', label: 'Экшен' },
  { value: 'adventure', label: 'Приключение' },
  { value: 'arcade', label: 'Аркада' },
  { value: 'puzzle', label: 'Головоломка' },
  { value: 'strategy', label: 'Стратегия' },
  { value: 'rpg', label: 'RPG' },
  { value: 'simulator', label: 'Симулятор' },
  { value: 'racing', label: 'Гонки' },
  { value: 'platformer', label: 'Платформер' },
  { value: 'horror', label: 'Хоррор' },
  { value: 'shooter', label: 'Шутер' },
  { value: 'visual_novel', label: 'Визуальная новелла' },
  { value: 'sport', label: 'Спорт' },
  { value: 'other', label: 'Другое' },
]

export function projectKindLabel(value: ProjectKind | string | null | undefined): string {
  return PROJECT_KINDS.find(option => option.value === value)?.label ?? (value ?? '')
}

export function devStatusLabel(value: ProjectDevStatus | string | null | undefined): string {
  return PROJECT_DEV_STATUSES.find(option => option.value === value)?.label ?? (value ?? '')
}

export function genreLabel(value: ProjectGenre | string | null | undefined): string {
  return PROJECT_GENRES.find(option => option.value === value)?.label ?? (value ?? '')
}
