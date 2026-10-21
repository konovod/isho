class MeSerializer < BaseSerializer
  def initialize(@user : User)
  end

  def render
    {
      id:              @user.id,
      email:           @user.email,
      username:        @user.username,
      display_name:    @user.display_name,
      bio:             @user.bio,
      theme:           @user.theme,
      is_admin:        @user.is_admin,
      email_confirmed: @user.email_confirmed?,
      created_at:      @user.created_at,
    }
  end
end
