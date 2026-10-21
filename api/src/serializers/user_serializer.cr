class UserSerializer < BaseSerializer
  def initialize(@user : User)
  end

  def render
    {
      id:           @user.id,
      username:     @user.username,
      display_name: @user.display_name,
      bio:          @user.bio,
      created_at:   @user.created_at,
    }
  end
end
