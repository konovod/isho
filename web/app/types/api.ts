export type Theme = 'light' | 'dark'

/** AI involvement, from the least to the most. */
export type AiUsage = 'ai_free' | 'partial' | 'significant' | 'full'

export interface ApiUser {
  id: number
  username: string
  display_name: string | null
  bio: string | null
  /** Short AI-made characteristic, shown under the nickname on the forum. */
  ai_flair?: string | null
  created_at: string
}

/** Limits of the forum AI features for the signed-in user. */
export interface MeAi {
  enabled: boolean
  answers_left: number
  answers_per_day: number
  flair: string | null
  flair_enabled: boolean
}

/** Set while an admin views the site as another account. */
export interface Impersonation {
  admin: ApiUser
  started_at: string
  expires_at: string
}

export interface Me extends ApiUser {
  email: string
  theme: Theme
  show_nsfw: boolean
  max_ai_usage: AiUsage
  is_admin: boolean
  email_confirmed: boolean
  ban: ActiveBan | null
  ai: MeAi
  impersonation: Impersonation | null
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
  /** Parent category, when this section is a subsection. */
  parent?: ForumSectionRef | null
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
  parent_id: number | null
  parent: ForumSectionRef | null
  depth: number
  children_count: number
  ai_answers_enabled: boolean
  topics_count: number
  posts_count: number
  unread_topics_count: number
}

/** A section as the moderation panel sees it: counts include every topic. */
export interface AdminForumSection {
  id: number
  slug: string
  title: string
  description: string | null
  group_title: string | null
  position: number
  parent_id: number | null
  parent: ForumSectionRef | null
  depth: number
  children_count: number
  ai_answers_enabled: boolean
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
  /** Only returned on the first page of the topic. */
  ai_answer: ForumAiAnswer | null
}

/** The model's opening answer to a topic; it is not a forum post. */
export interface ForumAiAnswer {
  id: number
  status: 'queued' | 'ready' | 'failed' | 'skipped'
  body: string | null
  model: string | null
  created_at: string
}

/** A section the model thinks fits a new topic better than the current one. */
export interface TopicSuggestion {
  section: ForumSectionRef
  confidence: number
  reason: string
}

export interface ForumPostQuote {
  post_id: number | null
  /** Page the quoted post is on, when known. */
  page: number | null
  author_name: string | null
  author_username: string | null
  body: string | null
}

export type ForumReactionKind = 'like' | 'dislike'

/** Counts on a post plus the reaction of the reader, when signed in. */
export interface ForumPostReactions {
  likes_count: number
  dislikes_count: number
  my_reaction: ForumReactionKind | null
}

/** Latest voters shown in the popup next to a counter. */
export interface ForumReactionVoters {
  kind: ForumReactionKind
  total: number
  items: ApiUser[]
  truncated: boolean
}

export interface ForumPost {
  id: number
  body: string
  author: ApiUser
  created_at: string
  updated_at: string
  edited: boolean
  quote: ForumPostQuote | null
  reactions: ForumPostReactions
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
  /** Counters, present only in the author's own responses. */
  downloads_count?: number
  launches_count?: number
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
  /** Id of the first browser build, so the card can offer «Играть». */
  play_build_id: number | null
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

export type JamPhase = 'draft' | 'upcoming' | 'open' | 'judging' | 'finished' | 'canceled'
export type JamStatus = 'draft' | 'published' | 'canceled'
export type JamEntryStatus = 'submitted' | 'disqualified'

export interface JamEntry {
  id: number
  status: JamEntryStatus
  created_at: string
  disqualified_reason: string | null
  disqualified_at: string | null
  project: ProjectCard
}

export interface JamEntryList {
  items: JamEntry[]
  meta: { page: number, per_page: number, total: number, pages: number }
}

/** A project's participation in a jam, shown on the project page. */
export interface ProjectJamEntry {
  id: number
  status: JamEntryStatus
  created_at: string
  disqualified_reason: string | null
  jam: {
    id: number
    slug: string
    title: string
    phase: JamPhase
    starts_at: string | null
    submissions_close_at: string | null
  }
}

export interface JamScoreValue {
  criterion_id: number
  score: number
  comment: string | null
}

/** One entry on the scoring page, with the viewer's current scorecard. */
export interface JamScoringEntry {
  entry: JamEntry
  complete: boolean
  my_scores: JamScoreValue[]
}

export interface JamScoringResponse {
  jam: Jam
  items: JamScoringEntry[]
  progress: { scored: number, total: number }
}

export interface JamCriterionResult {
  criterion_id: number
  title: string
  weight: number
  average: number
}

export interface JamResultEntry {
  entry_id: number
  place: number | null
  total: number
  max_total: number
  votes_count: number
  project: ProjectCard
  criteria: JamCriterionResult[]
}

export interface JamResults {
  available: boolean
  jam: {
    slug: string
    title: string
    phase: JamPhase
    judging_mode: string
    score_scale: number
    results_note: string | null
    voting_closes_at: string | null
    time_zone: string
  }
  items: JamResultEntry[]
}

export interface JamFeedbackItem {
  score: number
  comment: string | null
  counted: boolean
  voter: ApiUser | null
}

export interface JamFeedbackCriterion {
  id: number
  title: string
  weight: number
  average: number
  items: JamFeedbackItem[]
}

export interface JamFeedback {
  entry_id: number
  project: { slug: string, title: string }
  mode: string
  counted_votes: number
  total_votes: number
  criteria: JamFeedbackCriterion[]
}

export interface JamCriterion {
  id: number
  title: string
  description: string | null
  weight: number
  position: number
}

/** What the current account may do with a jam. */
export interface JamViewer {
  is_organizer: boolean
  is_admin: boolean
  can_edit: boolean
  can_submit: boolean
  can_score: boolean
  results_visible: boolean
  my_entries: JamEntry[]
}

export interface Jam {
  id: number
  slug: string
  title: string
  tagline: string | null
  theme: string | null
  theme_visible: boolean
  banner_url: string | null
  banner_card_url: string | null
  starts_at: string | null
  submissions_close_at: string | null
  voting_closes_at: string | null
  time_zone: string
  status: JamStatus
  phase: JamPhase
  next_phase_at: string | null
  judging_mode: string
  score_scale: number
  published_at: string | null
  canceled_at: string | null
  cancel_reason: string | null
  entries_count: number
  organizer: ApiUser
  /** Present on the detail endpoint. */
  description?: string | null
  rules?: string | null
  prizes?: string | null
  results_note?: string | null
  forum_section?: ForumSectionRef | null
  criteria?: JamCriterion[]
  viewer?: JamViewer | null
}

export interface JamList {
  items: Jam[]
  meta: { page: number, per_page: number, total: number, pages: number }
}

export interface JamCriterionList {
  items: JamCriterion[]
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
