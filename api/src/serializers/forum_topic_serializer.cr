class ForumTopicSerializer < BaseSerializer
  # `read_count` is the current user's read marker. It is nil for visitors,
  # who have nothing to compare against.
  def initialize(@topic : ForumTopic, @read_count : Int32? = nil)
  end

  def render
    {
      id:                @topic.id,
      slug:              @topic.slug,
      title:             @topic.title,
      section:           section,
      project:           project,
      author:            UserSerializer.new(@topic.user),
      last_post_author:  last_post_author,
      replies_count:     @topic.replies_count,
      last_post_at:      @topic.last_post_at,
      created_at:        @topic.created_at,
      updated_at:        @topic.updated_at,
      last_page:         last_page,
      read_posts_count:  @read_count,
      unread_count:      unread_count,
      first_unread_page: first_unread_page,
    }
  end

  private def section
    {
      id:    @topic.section.id,
      slug:  @topic.section.slug,
      title: @topic.section.title,
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
    @topic.last_post_user.try { |user| UserSerializer.new(user) }
  end

  private def unread_count : Int32
    read_count = @read_count
    return 0 unless read_count

    remaining = @topic.total_posts - read_count
    remaining.positive? ? remaining : 0
  end

  private def first_unread_page : Int32
    read_count = @read_count || 0
    page = read_count // AppSettings::FORUM_POSTS_PER_PAGE + 1
    page > last_page ? last_page : page
  end

  private def last_page : Int32
    total = @topic.total_posts
    per_page = AppSettings::FORUM_POSTS_PER_PAGE
    (total + per_page - 1) // per_page
  end
end
