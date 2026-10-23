class ForumSectionSerializer < BaseSerializer
  # `user` enables per-user unread counters and applies the viewer's content
  # preferences to project discussions; visitors get zeroes and fewer topics.
  def initialize(@section : ForumSection, @user : User? = nil)
  end

  def render
    topics = topics_count

    {
      id:          @section.id,
      slug:        @section.slug,
      title:       @section.title,
      description: @section.description,
      group_title: @section.group_title,
      position:    @section.position,
      # The new-topic form hides the "answer from AI" checkbox when a section
      # (or the whole server) has it off.
      ai_answers_enabled: @section.ai_answers_enabled,
      topics_count:       topics,
      # Every topic has an opening post, so replies_count + 1 is its post
      # count. This avoids joining the whole forum_posts table per section.
      posts_count:         topics + replies_count,
      unread_topics_count: unread_topics_count,
    }
  end

  private def topics_query : ForumTopicQuery
    query = ForumTopicQuery.new.section_id(@section.id)
    @section.slug == "projects" ? query.with_visible_project(@user) : query
  end

  private def topics_count : Int64
    topics_query.select_count
  end

  private def replies_count : Int64
    topics_query.replies_count.select_sum!
  end

  private def unread_topics_count : Int64
    user = @user
    return 0_i64 unless user

    topics_query.unread_for(user.id).select_count
  end
end
