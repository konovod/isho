class Api::V1::Admin::Projects::Unpublish < ApiAction
  include Api::Auth::RequireAdmin
  include Api::V1::Projects::ProjectParams

  post "/api/v1/admin/projects/:slug/unpublish" do
    unless project.published?
      json ErrorSerializer.new(
        code: "not_published",
        message: "Проект уже снят с публикации",
      ), status: 422
    else
      UnpublishProject.update!(project, params, moderator: current_user)
      json ProjectSerializer.new(reload_project(project), detailed: true, moderation: true)
    end
  end
end
