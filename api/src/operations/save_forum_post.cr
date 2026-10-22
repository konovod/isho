class SaveForumPost < ForumPost::SaveOperation
  permit_columns body

  # Optional excerpt the author highlighted; kept on the operation only and
  # stored into `quote_body` as part of the snapshot.
  attribute quote_text : String

  before_save do
    body.value = body.value.to_s.strip

    validate_required body
    validate_size_of body, max: AppSettings::FORUM_POST_MAX_CHARS

    apply_quote if new_record?
  end

  # A quote is a snapshot taken when the reply is created. Later edits or
  # deletions of the original post do not change it.
  private def apply_quote
    id = quoted_post_id.value
    return unless id

    quoted = ForumPostQuery.new
      .id(id)
      .topic_id(topic_id.value.not_nil!)
      .preload_user
      .first?

    unless quoted
      quoted_post_id.add_error "must be a post in this topic"
      return
    end

    excerpt = quote_text.value.to_s.strip
    text = excerpt.empty? ? quoted.body : excerpt

    quote_author_name.value = quoted.user.name
    quote_author_username.value = quoted.user.username
    quote_body.value = text[0, AppSettings::FORUM_QUOTE_MAX_CHARS]
  end
end
