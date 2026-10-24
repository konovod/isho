import type { AiUsage } from '~/types/api'

export interface AiUsageOption {
  value: AiUsage
  label: string
  description: string
}

/** Ordered from the least to the most AI involvement. */
export const AI_USAGE_OPTIONS: AiUsageOption[] = [
  {
    value: 'ai_free',
    label: 'Без ИИ',
    description: 'Проект сделан без ИИ.',
  },
  {
    value: 'partial',
    label: 'Частичное',
    description: 'Есть элементы арта/кода, сделанные ИИ.',
  },
  {
    value: 'significant',
    label: 'Значительное',
    description: 'Арт и/или код больше чем наполовину сделаны ИИ, но ручной труд присутствует.',
  },
  {
    value: 'full',
    label: 'Полное',
    description: 'Сделано агентом за день и/или меньше чем за 10 запросов.',
  },
]

export function aiUsageOption(value: AiUsage | string | null | undefined): AiUsageOption {
  return AI_USAGE_OPTIONS.find(option => option.value === value) ?? AI_USAGE_OPTIONS[0]!
}
