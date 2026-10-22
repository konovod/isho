export type Theme = 'light' | 'dark'

export interface ApiUser {
  id: number
  username: string
  display_name: string | null
  bio: string | null
  created_at: string
}

export interface Me extends ApiUser {
  email: string
  theme: Theme
  is_admin: boolean
  email_confirmed: boolean
}

export interface ForumSectionRef {
  id: number
  slug: string
  title: string
}

export interface ForumProjectRef {
  id: number
  slug: string
  title: string
}

export interface ForumSection {
  id: number
  slug: string
  title: string
  description: string | null
  group_title: string | null
  position: number
  topics_count: number
  posts_count: number
}

export interface ForumTopic {
  id: number
  slug: string
  title: string
  section: ForumSectionRef
  project: ForumProjectRef | null
  author: ApiUser
  replies_count: number
  last_post_at: string
  created_at: string
  updated_at: string
  last_page: number
}

export interface ForumPostQuote {
  post_id: number | null
  author_name: string | null
  author_username: string | null
  body: string | null
}

export interface ForumPost {
  id: number
  body: string
  author: ApiUser
  created_at: string
  updated_at: string
  edited: boolean
  quote: ForumPostQuote | null
}

export interface ForumMeta {
  page: number
  per_page: number
  total: number
  pages: number
}

export interface Tag {
  id: number
  name: string
  slug: string
}

/** Tag from the catalogue endpoint: popularity is counted over published projects. */
export interface TagSummary extends Tag {
  projects_count: number
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

export interface Devlog {
  id: number
  slug: string
  title: string
  body: string
  created_at: string
  updated_at: string
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
  moderation_note: string | null
  moderated_at: string | null
}

export interface ProjectList {
  items: ProjectCard[]
  meta: { page: number, per_page: number, total: number }
}

export interface AdminUser extends ApiUser {
  email: string
  is_admin: boolean
  email_confirmed: boolean
  projects_count: number
}

export interface AdminUserList {
  items: AdminUser[]
  meta: { page: number, per_page: number, total: number }
}

export interface ApiErrorPayload {
  error: {
    code: string
    message: string
    details?: Record<string, string[]> | null
  }
}
