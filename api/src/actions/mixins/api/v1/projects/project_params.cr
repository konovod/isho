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

  def tag_slugs : Array(String)
    params.get_all?(:tag_slugs) || [] of String
  end

  def sync_tags(project : Project) : Nil
    SetProjectTags.new(project: project, tag_slugs: tag_slugs).run if params.get_all?(:tag_slugs)
  end
end
