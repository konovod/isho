class Api::V1::Projects::Update < ApiAction
  include Api::V1::Projects::RequireOwner

  patch "/api/v1/projects/:slug" do
    SaveProject.update!(project, params)
    sync_tags(project)
    json ProjectSerializer.new(reload_project(project), detailed: true)
  end
end
