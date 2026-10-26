class ForumTopicSerializer < BaseSerializer
  # `read_count` is the current user's read marker. It is nil for visitors,
  # who have nothing to compare against. `ai_answer` is passed only on the
  # first page of the topic. `state` is present when the viewer has a
  # blacklist: it replaces the counter-based unread numbers with values that
  # ignore blocked authors.
  def initialize(
    @topic : ForumTopic,
    @read_count : Int32? = nil,
    @ai_answer : ForumAiAnswer? = nil,
    @state : ForumReadState::State? = nil,
    @blocked_user_ids : Array(Int64) = [] of Int64,
  )
  end

  def render
    {
      id:                   @topic.id,
      slug:                 @topic.slug,
      title:                @topic.title,
      section:              section,
      project:              project,
      author:               UserSerializer.new(@topic.user),
      last_post_author:     last_post_author,
      replies_count:        @topic.replies_count,
      last_post_at:         @topic.last_post_at,
      created_at:           @topic.created_at,
      updated_at:           @topic.updated_at,
      last_page:            last_page,
      read_posts_count:     @read_count,
      unread_count:         unread_count,
      first_unread_page:    first_unread_page,
      first_unread_post_id: @state.try(&.first_unread_post_id),
      ai_answer:            @ai_answer.try { |answer| ForumAiAnswerSerializer.new(answer) },
    }
  end

  private def section
    {
      id:     @topic.section.id,
      slug:   @topic.section.slug,
      title:  @topic.section.title,
      parent: parent_section,
    }
  end

  private def parent_section
    section = @topic.section
    return nil unless section.parent_id
    return nil unless section.parent_preloaded?

    value = section.parent
    return nil unless value

    {
      id:    value.id,
      slug:  value.slug,
      title: value.title,
    }
  end

  private def project
    value = @topic.project
    return nil unless value

    {
      id:    value.id,
      slug:  value.slug,
      title: value.title,
    }
  end

  private def last_post_author
    author_id = @topic.last_post_user_id
    return nil if author_id && @blocked_user_ids.includes?(author_id)

    @topic.last_post_user.try { |user| UserSerializer.new(user) }
  end

  private def unread_count : Int32
    state = @state
    return state.unread_count if state

    read_count = @read_count
    return 0 unless read_count

    remaining = @topic.total_posts - read_count
    remaining.positive? ? remaining : 0
  end

  private def first_unread_page : Int32
    state = @state
    return state.first_unread_page if state

    read_count = @read_count || 0
    page = read_count // AppSettings::FORUM_POSTS_PER_PAGE + 1
    page > last_page ? last_page : page
  end

  private def last_page : Int32
    state = @state
    total = state ? state.visible_total : @topic.total_posts
    per_page = AppSettings::FORUM_POSTS_PER_PAGE
    pages = (total + per_page - 1) // per_page
    pages.positive? ? pages : 1
  end
end
