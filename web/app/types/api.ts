export interface ApiUser {
  id: number
  username: string
  display_name: string | null
  bio: string | null
  created_at: string
}

export interface Me extends ApiUser {
  email: string
  is_admin: boolean
}

export interface Tag {
  id: number
  name: string
  slug: string
}

/** Tag chosen in the editor: `slug` is null until the server creates it. */
export interface TagDraft {
  name: string
  slug: string | null
}

export interface Screenshot {
  id: number
  caption: string | null
  position: number
  is_cover: boolean
  url: string | null
  card_url: string | null
  thumb_url: string | null
}

export interface Download {
  id: number
  label: string
  url: string
  platform: string | null
  version: string | null
}

export interface ProjectCard {
  id: number
  slug: string
  title: string
  tagline: string | null
  kind: string
  status: string
  published_at: string | null
  cover_url: string | null
  author: ApiUser
  tags: Tag[]
}

export interface ProjectDetail extends ProjectCard {
  description: string | null
  screenshots: Screenshot[]
  downloads: Download[]
}

export interface ProjectList {
  items: ProjectCard[]
  meta: { page: number, per_page: number, total: number }
}

export interface ApiErrorPayload {
  error: {
    code: string
    message: string
    details?: Record<string, string[]> | null
  }
}
