class BlockedUserSerializer < BaseSerializer
  def initialize(@block : UserBlock)
  end

  def render
    {
      user:       UserSerializer.new(@block.blocked_user),
      blocked_at: @block.created_at,
    }
  end
end
