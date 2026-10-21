class Api::V1::Projects::Devlogs::Index < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Projects::ProjectParams

  get "/api/v1/projects/:slug/devlogs" do
    unless project_visible?
      raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
    end

    devlogs = DevlogQuery.new
      .project_id(project.id)
      .newest
      .results

    json({items: devlogs.map { |devlog| DevlogSerializer.new(devlog) }})
  end
end
