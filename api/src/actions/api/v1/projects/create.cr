class Api::V1::Projects::Create < ApiAction
  include Api::V1::Projects::ProjectParams
  include Api::Auth::RequireNotBanned

  post "/api/v1/projects" do
    project = SaveProject.create!(params, user_id: current_user.id)
    sync_tags(project)
    json ProjectSerializer.new(reload_project(project), detailed: true, with_usage: true), status: 201
  end
end
