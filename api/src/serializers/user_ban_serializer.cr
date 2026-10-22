class UserBanSerializer < BaseSerializer
  def initialize(@ban : UserBan)
  end

  def render
    {
      id:         @ban.id,
      reason:     @ban.reason,
      banned_at:  @ban.created_at,
      expires_at: @ban.expires_at,
      active:     @ban.active?,
      lifted_at:  @ban.lifted_at,
      banned_by:  @ban.banned_by.try(&.username),
      lifted_by:  @ban.lifted_by.try(&.username),
    }
  end
end
