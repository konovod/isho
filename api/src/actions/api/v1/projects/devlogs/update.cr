class Api::V1::Projects::Devlogs::Update < ApiAction
  include Api::V1::Projects::RequireOwner

  patch "/api/v1/projects/:slug/devlogs/:id" do
    devlog = DevlogQuery.new
      .id(params.get(:id))
      .project_id(project.id)
      .first? || raise Avram::RecordNotFoundError.new(Devlog.table_name, params.get(:id).to_s)

    updated = SaveDevlog.update!(devlog, params)
    json DevlogSerializer.new(updated)
  end
end
