class Api::V1::PasswordResets::Update < ApiAction
  include Api::Auth::SkipRequireSession
  include Lucky::RateLimit
  rate_limit to: 10, within: 10.minutes

  post "/api/v1/password_resets/:token" do
    user = PasswordReset.find(params.get(:token)) ||
           raise Api::InvalidPasswordResetTokenError.new

    # The new password and the one-time token are written in one operation.
    # The link also proves control of the mailbox, so the address becomes
    # confirmed without waiting for a separate letter.
    updated = ResetPassword.update!(
      user,
      params,
      password_reset_token_hash: nil,
      password_reset_sent_at: nil,
      email_confirmation_token_hash: nil,
      email_confirmation_sent_at: nil,
      email_confirmed_at: user.email_confirmed_at || Time.utc,
    )

    # Sessions opened with the old password must not survive the reset.
    ::Auth::Session.destroy_all(updated)
    sign_in(updated)

    json MeSerializer.new(updated)
  end

  private def rate_limit_identifier : String
    ip = context.request.remote_ip
    ip.nil? || ip.empty? ? "unknown" : ip
  end
end
