class ForumTopicSerializer < BaseSerializer
  def initialize(@topic : ForumTopic)
  end

  def render
    {
      id:            @topic.id,
      slug:          @topic.slug,
      title:         @topic.title,
      section:       section,
      project:       project,
      author:        UserSerializer.new(@topic.user),
      replies_count: @topic.replies_count,
      last_post_at:  @topic.last_post_at,
      created_at:    @topic.created_at,
      updated_at:    @topic.updated_at,
      last_page:     last_page,
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

  private def last_page : Int32
    total = @topic.total_posts
    per_page = AppSettings::FORUM_POSTS_PER_PAGE
    (total + per_page - 1) // per_page
  end
end
