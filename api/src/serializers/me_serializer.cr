class MeSerializer < BaseSerializer
  def initialize(@user : User, @impersonation : Auth::Impersonation? = nil)
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
      # Starting value for the header badge; the messages pages keep it fresh
      # from their own responses.
      unread_messages_count: DirectMessages.unread_count(@user),
      ban:                   ban ? ActiveBanSerializer.new(ban) : nil,
      ai:                    ai,
      impersonation:         impersonation,
    }
  end

  # Present while an admin views the site as this account. The client shows a
  # banner with the way back; the account itself has no admin powers here.
  private def impersonation
    imp = @impersonation
    return nil unless imp

    {
      admin:      UserSerializer.new(imp.admin),
      started_at: imp.session.created_at,
      expires_at: imp.session.expires_at,
    }
  end

  # Limits and preferences of the forum AI features, used by the composer to
  # show the remaining answers and by the settings page.
  private def ai
    {
      enabled:         Ai.enabled?,
      answers_left:    Ai::Quota.left(@user, "forum_answer", AppSettings::AI_FORUM_ANSWERS_PER_DAY),
      answers_per_day: AppSettings::AI_FORUM_ANSWERS_PER_DAY,
      flair:           @user.visible_ai_flair,
      flair_enabled:   @user.ai_flair_enabled,
    }
  end
end
