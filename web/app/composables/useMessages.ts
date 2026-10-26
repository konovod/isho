/**
 * Unread badge for the header. Messages pages receive the authoritative count
 * with every response and write it here, so a stale `me` payload never wins
 * over a conversation that was just read. The account id is stored with the
 * number: signing in as somebody else must not leave the previous badge.
 */
export function useMessages() {
  const { user } = useAuth()
  const stored = useState<{ userId: number, count: number } | null>('messages.unread', () => null)

  const unreadCount = computed(() => {
    const current = user.value
    if (!current) return 0
    if (stored.value?.userId === current.id) return stored.value.count

    return current.unread_messages_count ?? 0
  })

  function setUnreadCount(value: number) {
    const current = user.value
    if (!current) return

    stored.value = { userId: current.id, count: Math.max(0, value) }
  }

  return { unreadCount, setUnreadCount }
}
