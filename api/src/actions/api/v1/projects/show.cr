class Api::V1::Projects::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Projects::ProjectParams

  get "/api/v1/projects/:slug" do
    visible = project.published? || (current_user? && project.user_id == current_user?.try(&.id))

    unless visible
      raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
    end

    can_moderate = current_user?.try { |user| user.id == project.user_id || user.moderator? } || false
    json ProjectSerializer.new(project, detailed: true, moderation: can_moderate)
  end
end
