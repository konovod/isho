class AdminUserSerializer < BaseSerializer
  def initialize(@user : User, @projects_count : Int64)
  end

  def render
    ban = @user.active_ban

    {
      id:              @user.id,
      email:           @user.email,
      username:        @user.username,
      display_name:    @user.display_name,
      bio:             @user.bio,
      is_admin:        @user.is_admin,
      email_confirmed: @user.email_confirmed?,
      projects_count:  @projects_count,
      created_at:      @user.created_at,
      ban:             ban ? ActiveBanSerializer.new(ban) : nil,
    }
  end
end
