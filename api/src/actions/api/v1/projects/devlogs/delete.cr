class Api::V1::Projects::Devlogs::Delete < ApiAction
  include Api::V1::Projects::RequireOwner

  delete "/api/v1/projects/:slug/devlogs/:id" do
    devlog = DevlogQuery.new
      .id(params.get(:id))
      .project_id(project.id)
      .first? || raise Avram::RecordNotFoundError.new(Devlog.table_name, params.get(:id).to_s)

    Devlog::DeleteOperation.delete!(devlog)
    head 204
  end
end
