module Api::V1::Projects::ProjectParams
  memoize def project : Project
    ProjectQuery.new
      .slug(params.get(:slug))
      .preload_user
      .preload_screenshots
      .preload_downloads
      .preload_tags
      .first? || raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
  end

  def reload_project(project : Project) : Project
    ProjectQuery.new
      .id(project.id)
      .preload_user
      .preload_screenshots
      .preload_downloads
      .preload_tags
      .first? || raise Avram::RecordNotFoundError.new(Project.table_name, project.id.to_s)
  end

  # `tag_names` are human-readable names; unknown ones become new tags.
  # `tag_slugs` is kept for backwards compatibility and matches existing tags.
  def tag_names : Array(String)?
    params.get_all?(:tag_names) || params.get_all?(:tag_slugs)
  end

  def sync_tags(project : Project) : Nil
    names = tag_names
    SetProjectTags.new(project: project, tag_names: names).run if names
  end
end
