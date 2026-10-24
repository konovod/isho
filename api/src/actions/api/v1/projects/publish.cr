class Api::V1::Projects::Publish < ApiAction
  include Api::V1::Projects::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/projects/:slug/publish" do
    ChangeProjectStatus.new(project: project, publish: true).run
    json ProjectSerializer.new(reload_project(project), detailed: true, moderation: true, with_usage: true)
  end
end
