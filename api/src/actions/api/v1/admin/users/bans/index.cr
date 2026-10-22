class Api::V1::Admin::Users::Bans::Index < ApiAction
  include Api::Auth::RequireAdmin

  get "/api/v1/admin/users/:username/bans" do
    user = UserQuery.new.by_username(params.get(:username)).first? ||
           raise Avram::RecordNotFoundError.new(User.table_name, params.get(:username).to_s)

    bans = UserBanQuery.new
      .for_user(user.id)
      .newest_first
      .preload_banned_by
      .preload_lifted_by
      .results

    json({
      items: bans.map { |ban| UserBanSerializer.new(ban) },
    })
  end
end
