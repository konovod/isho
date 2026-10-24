# Counts every topic of the section, including discussions of drafts in
# "projects" that the public serializer hides from visitors.
class AdminForumSectionSerializer < BaseSerializer
  def initialize(@section : ForumSection)
  end

  def render
    topics = ForumTopicQuery.new.section_id(@section.id).select_count

    {
      id:                 @section.id,
      slug:               @section.slug,
      title:              @section.title,
      description:        @section.description,
      group_title:        @section.group_title,
      position:           @section.position,
      parent_id:          @section.parent_id,
      parent:             parent,
      depth:              @section.parent_id ? 1 : 0,
      children_count:     children_count,
      ai_answers_enabled: @section.ai_answers_enabled,
      topics_count:       topics,
      posts_count:        topics + ForumTopicQuery.new.section_id(@section.id).replies_count.select_sum!,
    }
  end

  private def parent
    return nil unless @section.parent_id
    return nil unless @section.parent_preloaded?

    value = @section.parent
    return nil unless value

    {id: value.id, slug: value.slug, title: value.title}
  end

  private def children_count : Int64
    ForumSectionQuery.new.children_of(@section.id).select_count
  end
end
