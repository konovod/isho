export type Theme = 'light' | 'dark'

/** AI involvement, from the least to the most. */
export type AiUsage = 'ai_free' | 'partial' | 'significant' | 'full'

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
  show_nsfw: boolean
  max_ai_usage: AiUsage
  is_admin: boolean
  email_confirmed: boolean
  ban: ActiveBan | null
}

/** Active moderation ban shown to the user and in the admin list. */
export interface ActiveBan {
  id: number
  reason: string
  banned_at: string
  banned_until: string
  days_left: number
}

/** One row of the ban history kept for moderators. */
export interface UserBanRecord {
  id: number
  reason: string
  banned_at: string
  expires_at: string
  active: boolean
  lifted_at: string | null
  banned_by: string | null
  lifted_by: string | null
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
  unread_topics_count: number
}

export interface ForumTopic {
  id: number
  slug: string
  title: string
  section: ForumSectionRef
  project: ForumProjectRef | null
  author: ApiUser
  last_post_author: ApiUser | null
  replies_count: number
  last_post_at: string
  created_at: string
  updated_at: string
  last_page: number
  /** Posts already seen by the current user; null for visitors. */
  read_posts_count: number | null
  unread_count: number
  first_unread_page: number
}

export interface ForumPostQuote {
  post_id: number | null
  /** Page the quoted post is on, when known. */
  page: number | null
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

/** A post the author is about to quote, narrowed to a selected fragment. */
export interface ForumQuoteDraft {
  post: ForumPost
  text: string
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

/** An image uploaded from the Markdown editor and inserted by URL. */
export interface MarkdownImage {
  id: number
  url: string
}

export interface Download {
  id: number
  label: string
  url: string
  platform: string | null
  version: string | null
}

/** A file or a browser build hosted by isho. */
export interface Build {
  id: number
  kind: 'file' | 'web'
  label: string
  platform: string | null
  version: string | null
  size_bytes: number
  /** Download URL for `kind: 'file'`, null for browser builds. */
  url: string | null
  /** Entry URL for `kind: 'web'`, null for downloadable files. */
  play_url: string | null
  entry_path: string | null
  created_at: string
}

export interface StorageProjectUsage {
  slug: string
  title: string
  used_bytes: number
}

export interface StorageUsage {
  used_bytes: number
  builds_bytes: number
  sessions_bytes: number
  images_bytes: number
  limit_bytes: number
  project_limit_bytes: number
  server_used_bytes: number
  server_limit_bytes: number
  server_free_bytes: number | null
  server_reserve_bytes: number
  projects: StorageProjectUsage[]
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
  nsfw: boolean
  ai_usage: AiUsage
  published_at: string | null
  cover_url: string | null
  author: ApiUser
  tags: Tag[]
}

export interface ProjectDetail extends ProjectCard {
  description: string | null
  screenshots: Screenshot[]
  downloads: Download[]
  builds: Build[]
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
  ban: ActiveBan | null
}

export interface AdminUserList {
  items: AdminUser[]
  meta: { page: number, per_page: number, total: number }
}

/** Address of a deleted account that cannot register again. */
export interface AdminBlockedEmail {
  id: number
  email: string
  /** Username of the account when it was deleted, for context. */
  username: string | null
  created_at: string
}

export interface AdminBlockedEmailList {
  items: AdminBlockedEmail[]
  meta: { page: number, per_page: number, total: number }
}

export interface ApiErrorPayload {
  error: {
    code: string
    message: string
    details?: Record<string, string[]> | null
  }
}
