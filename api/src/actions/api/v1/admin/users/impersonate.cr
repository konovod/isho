class Api::V1::Admin::Users::Impersonate < ApiAction
  include Api::Auth::RequireAdmin

  # Opens a short, read-only session for another account. The admin keeps their
  # own cookie, so `DELETE /api/v1/impersonation` just drops this one.
  post "/api/v1/admin/users/:username/impersonate" do
    user = UserQuery.new.by_username(params.get(:username)).first? ||
           raise Avram::RecordNotFoundError.new(User.table_name, params.get(:username).to_s)

    if user.id == current_user.id
      json ErrorSerializer.new(
        code: "cannot_impersonate_self",
        message: "Нельзя войти от имени своего аккаунта",
      ), status: 422
    elsif user.moderator?
      json ErrorSerializer.new(
        code: "cannot_impersonate_admin",
        message: "Нельзя войти от имени администратора",
      ), status: 422
    else
      imp = start_impersonation(user)
      Log.info { "impersonation.start admin_id=#{imp.admin.id} user_id=#{user.id} ip=#{context.request.remote_ip}" }
      json MeSerializer.new(user, imp)
    end
  end
end
