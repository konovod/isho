class Api::V1::Projects::Publish < ApiAction
  include Api::V1::Projects::RequireOwner

  post "/api/v1/projects/:slug/publish" do
    ChangeProjectStatus.new(project: project, publish: true).run
    json ProjectSerializer.new(reload_project(project), detailed: true)
  end
end
