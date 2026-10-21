class ForumTopicQuery < ForumTopic::BaseQuery
  def newest_activity
    last_post_at.desc_order
  end

  def for_section(section_id : Int64)
    section_id(section_id)
  end

  def for_project(project_id : Int64)
    project_id(project_id)
  end

  def by_slug(slug : String)
    slug(slug)
  end

  # Project discussions live in the public "projects" section. Draft projects
  # must not leak there, so only topics of published projects are listed.
  def with_published_project
    join_project(ProjectQuery.new.published)
  end
end
