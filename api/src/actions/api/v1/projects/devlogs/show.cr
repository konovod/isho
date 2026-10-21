class Api::V1::Projects::Devlogs::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Projects::ProjectParams

  get "/api/v1/projects/:slug/devlogs/:devlog_slug" do
    unless project_visible?
      raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
    end

    devlog = DevlogQuery.new
      .project_id(project.id)
      .slug(params.get(:devlog_slug))
      .first? || raise Avram::RecordNotFoundError.new(Devlog.table_name, params.get(:devlog_slug).to_s)

    json DevlogSerializer.new(devlog)
  end
end
