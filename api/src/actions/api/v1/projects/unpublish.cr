class Api::V1::Projects::Unpublish < ApiAction
  include Api::V1::Projects::RequireOwner

  post "/api/v1/projects/:slug/unpublish" do
    ChangeProjectStatus.new(project: project, publish: false).run
    json ProjectSerializer.new(reload_project(project), detailed: true, moderation: true)
  end
end
