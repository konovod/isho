import type { Build } from '~/types/api'
import { ApiError } from '~/composables/useApi'

/** One request carries at most this many bytes; the server tells us too. */
export const BUILD_CHUNK_SIZE = 8_000_000

export interface BuildUploadInput {
  kind: 'file' | 'web'
  label?: string
  platform?: string
  version?: string
  entry?: string
}

interface UploadTicket {
  token: string
  chunk_size: number
  total_bytes: number
  received_bytes: number
}

export function useBuildUpload(slug: string) {
  const config = useRuntimeConfig()
  const base = config.public.apiBase as string

  const uploading = ref(false)
  const progress = ref(0)
  const uploaded = ref(0)
  const total = ref(0)
  const cancelled = ref(false)

  let controller: AbortController | null = null
  let token: string | null = null

  function toApiError(error: any): ApiError {
    if (error instanceof ApiError) return error

    const payload = (error?.data ?? error?.response?._data)?.error
    return new ApiError(
      payload?.code ?? 'network_error',
      payload?.message ?? 'Не удалось загрузить файл',
      payload?.details ?? null,
    )
  }

  async function request<T>(path: string, options: Record<string, any> = {}): Promise<T> {
    const fetchOptions: Record<string, any> = { ...options }
    if (controller) fetchOptions.signal = controller.signal

    try {
      return await $fetch<T>(`${base}${path}`, fetchOptions)
    }
    catch (error) {
      throw toApiError(error)
    }
  }

  async function upload(file: File, input: BuildUploadInput): Promise<Build> {
    uploading.value = true
    cancelled.value = false
    progress.value = 0
    uploaded.value = 0
    total.value = file.size
    controller = new AbortController()
    token = null

    try {
      const ticket = await request<UploadTicket>(`/api/v1/projects/${slug}/uploads`, {
        method: 'POST',
        body: {
          upload: {
            kind: input.kind,
            filename: file.name,
            total_bytes: file.size,
          },
        },
      })

      token = ticket.token
      uploaded.value = Math.min(ticket.received_bytes, file.size)
      progress.value = file.size ? Math.round((uploaded.value / file.size) * 100) : 100

      const chunkSize = ticket.chunk_size || BUILD_CHUNK_SIZE
      while (uploaded.value < file.size) {
        const start = uploaded.value
        const end = Math.min(start + chunkSize, file.size)
        const index = Math.floor(start / chunkSize)

        await putChunk(ticket.token, index, file.slice(start, end))

        uploaded.value = end
        progress.value = Math.round((end / file.size) * 100)
      }

      const build = await request<Build>(`/api/v1/projects/${slug}/uploads/${ticket.token}/finish`, {
        method: 'POST',
        body: {
          build: {
            label: input.label,
            platform: input.platform,
            version: input.version,
            entry: input.entry,
          },
        },
      })

      token = null
      return build
    }
    catch (error) {
      if (cancelled.value) {
        if (token) await cancel()
        throw new ApiError('upload_cancelled', 'Загрузка отменена')
      }

      if (token) await cancel()
      throw toApiError(error)
    }
    finally {
      uploading.value = false
      controller = null
    }
  }

  async function putChunk(uploadToken: string, index: number, blob: Blob): Promise<void> {
    for (let attempt = 1; ; attempt++) {
      try {
        await request(`/api/v1/projects/${slug}/uploads/${uploadToken}/chunks/${index}`, {
          method: 'PUT',
          body: blob,
          headers: { 'Content-Type': 'application/octet-stream' },
        })
        return
      }
      catch (error) {
        if (attempt >= 3 || cancelled.value) throw error
        await new Promise(resolve => setTimeout(resolve, 500 * attempt))
      }
    }
  }

  async function cancel(): Promise<void> {
    const current = token
    token = null
    cancelled.value = true
    controller?.abort()
    controller = null
    uploading.value = false

    if (!current) return

    try {
      await $fetch(`${base}/api/v1/projects/${slug}/uploads/${current}`, { method: 'DELETE' })
    }
    catch {
      // The session may already be gone; the cleanup task will catch it.
    }
  }

  return { uploading, progress, uploaded, total, cancelled, upload, cancel }
}
