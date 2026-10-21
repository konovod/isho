require "digest/sha256"
require "random/secure"

# One-time links that prove an email address belongs to the account. The
# database keeps only a SHA-256 digest, so a database leak cannot be replayed.
module EmailConfirmation
  def self.required? : Bool
    AppSettings.email_confirmation_required?
  end

  # Stores a fresh token for the user and returns the raw value for the link.
  def self.issue(user : User) : String
    token = Random::Secure.urlsafe_base64(AppSettings::EMAIL_CONFIRMATION_BYTES)

    SaveEmailConfirmation.update!(
      user,
      email_confirmation_token_hash: digest(token),
      email_confirmation_sent_at: Time.utc,
    )

    token
  end

  # Issues a token and emails the confirmation link. Returns the user again so
  # callers can serialize the current state.
  def self.send_to(user : User) : User
    token = issue(user)
    EmailConfirmationEmail.new(user, token).deliver
    user
  end

  # Returns the user when the token is valid and not expired. A token can be
  # used once: confirming clears it.
  def self.confirm(token : String) : User?
    return nil if token.strip.empty?

    user = UserQuery.new.email_confirmation_token_hash(digest(token)).first?
    return nil unless user
    return user if user.email_confirmed?
    return nil unless token_valid?(user)

    ConfirmUserEmail.update!(
      user,
      email_confirmed_at: Time.utc,
      email_confirmation_token_hash: nil,
      email_confirmation_sent_at: nil,
    )
  end

  # Time left before another letter may be sent, or nil when resending is fine.
  def self.resend_in(user : User) : Time::Span?
    sent_at = user.email_confirmation_sent_at
    return nil unless sent_at

    elapsed = Time.utc - sent_at
    return nil if elapsed >= AppSettings::EMAIL_CONFIRMATION_RESEND_INTERVAL

    AppSettings::EMAIL_CONFIRMATION_RESEND_INTERVAL - elapsed
  end

  def self.token_valid?(user : User) : Bool
    sent_at = user.email_confirmation_sent_at
    return false unless sent_at

    sent_at >= AppSettings::EMAIL_CONFIRMATION_TTL.ago
  end

  def self.digest(token : String) : String
    Digest::SHA256.hexdigest(token)
  end
end
