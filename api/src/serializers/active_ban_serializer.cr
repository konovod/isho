class ActiveBanSerializer < BaseSerializer
  def initialize(@ban : UserBan)
  end

  def render
    {
      id:           @ban.id,
      reason:       @ban.reason,
      banned_at:    @ban.created_at,
      banned_until: @ban.expires_at,
      days_left:    @ban.days_left,
    }
  end
end
