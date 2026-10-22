class ForumSectionSerializer < BaseSerializer
  # `user_id` enables per-user unread counters; visitors get zeroes.
  def initialize(@section : ForumSection, @user_id : Int64? = nil)
  end

  def render
    topics = topics_count

    {
      id:           @section.id,
      slug:         @section.slug,
      title:        @section.title,
      description:  @section.description,
      group_title:  @section.group_title,
      position:     @section.position,
      topics_count: topics,
      # Every topic has an opening post, so replies_count + 1 is its post
      # count. This avoids joining the whole forum_posts table per section.
      posts_count:         topics + replies_count,
      unread_topics_count: unread_topics_count,
    }
  end

  private def topics_query : ForumTopicQuery
    query = ForumTopicQuery.new.section_id(@section.id)
    @section.slug == "projects" ? query.with_published_project : query
  end

  private def topics_count : Int64
    topics_query.select_count
  end

  private def replies_count : Int64
    topics_query.replies_count.select_sum!
  end

  private def unread_topics_count : Int64
    user_id = @user_id
    return 0_i64 unless user_id

    topics_query.unread_for(user_id).select_count
  end
end
