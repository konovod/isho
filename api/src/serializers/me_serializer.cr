class MeSerializer < BaseSerializer
  def initialize(@user : User)
  end

  def render
    ban = @user.active_ban

    {
      id:              @user.id,
      email:           @user.email,
      username:        @user.username,
      display_name:    @user.display_name,
      bio:             @user.bio,
      theme:           @user.theme,
      show_nsfw:       @user.show_nsfw,
      max_ai_usage:    @user.max_ai_usage,
      is_admin:        @user.is_admin,
      email_confirmed: @user.email_confirmed?,
      created_at:      @user.created_at,
      ban:             ban ? ActiveBanSerializer.new(ban) : nil,
    }
  end
end
