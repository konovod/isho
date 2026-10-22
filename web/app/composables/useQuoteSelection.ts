export interface ForumQuoteSelection {
  postId: number
  text: string
  top: number
  left: number
}

const POPOVER_WIDTH = 132

function bodyOf(node: Node | null): HTMLElement | null {
  const element = node instanceof Element ? node : node?.parentElement
  return element?.closest<HTMLElement>('[data-quote-body]') ?? null
}

/**
 * Tracks a text selection inside a single forum post body, so the page can
 * offer quoting just the highlighted fragment. The button is positioned in
 * viewport coordinates because it is rendered with `position: fixed`.
 */
export function useQuoteSelection() {
  const selection = ref<ForumQuoteSelection | null>(null)
  let frame = 0

  function read() {
    const current = window.getSelection()

    if (!current || current.isCollapsed || current.rangeCount === 0) {
      selection.value = null
      return
    }

    const range = current.getRangeAt(0)
    const start = bodyOf(range.startContainer)
    const end = bodyOf(range.endContainer)

    // A selection spanning two posts (or a quote card) is not a fragment of one message.
    if (!start || start !== end) {
      selection.value = null
      return
    }

    const postId = Number(start.dataset.postId)
    const text = current.toString().trim().slice(0, FORUM_QUOTE_MAX_CHARS)

    if (!text || !Number.isFinite(postId)) {
      selection.value = null
      return
    }

    const rect = range.getBoundingClientRect()
    const fitsBelow = rect.bottom + 44 < window.innerHeight

    selection.value = {
      postId,
      text,
      top: fitsBelow ? rect.bottom + 8 : Math.max(8, rect.top - 40),
      left: Math.min(
        Math.max(8, rect.left),
        Math.max(8, window.innerWidth - POPOVER_WIDTH - 8),
      ),
    }
  }

  function schedule() {
    cancelAnimationFrame(frame)
    frame = requestAnimationFrame(read)
  }

  onMounted(() => {
    document.addEventListener('selectionchange', schedule)
    window.addEventListener('scroll', schedule, { capture: true, passive: true })
    window.addEventListener('resize', schedule)
  })

  onBeforeUnmount(() => {
    document.removeEventListener('selectionchange', schedule)
    window.removeEventListener('scroll', schedule, { capture: true })
    window.removeEventListener('resize', schedule)
    cancelAnimationFrame(frame)
  })

  function clear() {
    selection.value = null
    window.getSelection()?.removeAllRanges()
  }

  return { selection, clear }
}
