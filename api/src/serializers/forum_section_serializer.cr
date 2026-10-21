class ForumSectionSerializer < BaseSerializer
  def initialize(@section : ForumSection)
  end

  def render
    {
      id:           @section.id,
      slug:         @section.slug,
      title:        @section.title,
      description:  @section.description,
      group_title:  @section.group_title,
      position:     @section.position,
      topics_count: topics_count,
      posts_count:  posts_count,
    }
  end

  private def topics_query : ForumTopicQuery
    query = ForumTopicQuery.new.section_id(@section.id)
    @section.slug == "projects" ? query.with_published_project : query
  end

  private def topics_count : Int64
    topics_query.select_count
  end

  private def posts_count : Int64
    ForumPostQuery.new.join_topic(topics_query).select_count
  end
end
