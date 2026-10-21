class AdminUserSerializer < BaseSerializer
  def initialize(@user : User, @projects_count : Int64)
  end

  def render
    {
      id:             @user.id,
      email:          @user.email,
      username:       @user.username,
      display_name:   @user.display_name,
      bio:            @user.bio,
      is_admin:       @user.is_admin,
      projects_count: @projects_count,
      created_at:     @user.created_at,
    }
  end
end
