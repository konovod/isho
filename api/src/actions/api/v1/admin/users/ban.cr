class Api::V1::Admin::Users::Ban < ApiAction
  include Api::Auth::RequireAdmin

  post "/api/v1/admin/users/:username/ban" do
    user = UserQuery.new.by_username(params.get(:username)).first? ||
           raise Avram::RecordNotFoundError.new(User.table_name, params.get(:username).to_s)

    if user.id == current_user.id
      json ErrorSerializer.new(
        code: "cannot_ban_self",
        message: "Нельзя забанить свой аккаунт",
      ), status: 422
    elsif user.moderator?
      json ErrorSerializer.new(
        code: "cannot_ban_admin",
        message: "Нельзя забанить администратора",
      ), status: 422
    else
      BanUser.run(params, user: user, moderator: current_user) do |operation, _ban|
        if operation.valid?
          json AdminUserSerializer.new(user, ProjectQuery.new.for_user(user.id).select_count)
        else
          raise Avram::InvalidOperationError.new(operation)
        end
      end
    end
  end
end
