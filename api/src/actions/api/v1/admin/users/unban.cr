class Api::V1::Admin::Users::Unban < ApiAction
  include Api::Auth::RequireAdmin

  delete "/api/v1/admin/users/:username/ban" do
    user = UserQuery.new.by_username(params.get(:username)).first? ||
           raise Avram::RecordNotFoundError.new(User.table_name, params.get(:username).to_s)

    if ban = UserBanQuery.new.for_user(user.id).active.newest_first.first?
      LiftBan.run!(ban: ban, moderator: current_user)
    end

    json AdminUserSerializer.new(user, ProjectQuery.new.for_user(user.id).select_count)
  end
end
