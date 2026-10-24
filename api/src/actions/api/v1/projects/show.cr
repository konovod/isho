class Api::V1::Projects::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Projects::ProjectParams

  get "/api/v1/projects/:slug" do
    unless project_visible?
      raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
    end

    owner = current_user?.try { |user| user.id == project.user_id } || false
    can_moderate = owner || (current_user?.try(&.moderator?) || false)
    json ProjectSerializer.new(project, detailed: true, moderation: can_moderate, with_usage: owner)
  end
end
