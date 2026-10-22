class BlockedEmailSerializer < BaseSerializer
  def initialize(@entry : BlockedEmail)
  end

  def render
    {
      id:         @entry.id,
      email:      @entry.email,
      username:   @entry.username,
      created_at: @entry.created_at,
    }
  end
end
