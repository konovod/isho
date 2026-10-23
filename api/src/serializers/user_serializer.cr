class UserSerializer < BaseSerializer
  def initialize(@user : User)
  end

  def render
    {
      id:           @user.id,
      username:     @user.username,
      display_name: @user.display_name,
      bio:          @user.bio,
      # Shown under the nickname on the forum, never in the catalogue.
      ai_flair:   @user.visible_ai_flair,
      created_at: @user.created_at,
    }
  end
end
