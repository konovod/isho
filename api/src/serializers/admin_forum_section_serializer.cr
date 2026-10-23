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
      ai_answers_enabled: @section.ai_answers_enabled,
      topics_count:       topics,
      posts_count:        topics + ForumTopicQuery.new.section_id(@section.id).replies_count.select_sum!,
    }
  end
end
