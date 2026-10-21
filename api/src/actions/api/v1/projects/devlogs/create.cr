class Api::V1::Projects::Devlogs::Create < ApiAction
  include Api::V1::Projects::RequireOwner

  post "/api/v1/projects/:slug/devlogs" do
    devlog = SaveDevlog.create!(params, project_id: project.id)
    json DevlogSerializer.new(devlog), status: 201
  end
end
