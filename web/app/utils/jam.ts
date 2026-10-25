export function jamJudgingModeLabel(mode: string): string {
  return mode === 'participants' ? 'Только участники' : 'Все пользователи'
}

export function jamJudgingModeHint(mode: string): string {
  if (mode === 'participants') {
    return 'В итоговые баллы идут только оценки участников с поданной заявкой. Голосовать и оставлять отзывы могут все пользователи.'
  }

  return 'В итоговые баллы идут оценки всех пользователей. Голосовать и оставлять отзывы могут все.'
}
