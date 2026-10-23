require "digest/sha256"
require "random/secure"

# One-time links that let a user choose a new password. The database keeps only
# a SHA-256 digest, so a database leak cannot be replayed.
module PasswordReset
  # Stores a fresh token for the user and returns the raw value for the link.
  def self.issue(user : User) : String
    token = Random::Secure.urlsafe_base64(AppSettings::PASSWORD_RESET_BYTES)

    SavePasswordReset.update!(
      user,
      password_reset_token_hash: digest(token),
      password_reset_sent_at: Time.utc,
    )

    token
  end

  # Issues a token and emails the link. A request within the cooldown is
  # ignored, so the public endpoint cannot be used to flood a mailbox.
  def self.deliver(user : User) : Nil
    return if resend_in(user)

    token = issue(user)
    PasswordResetEmail.new(user, token).deliver
  rescue error
    # A letter that never left must not block the next attempt: drop the token
    # so the user can ask again right away.
    clear(user)
    raise error
  end

  # Returns the user when the token is valid. The caller clears it together
  # with the new password, so the link works exactly once.
  def self.find(token : String) : User?
    return nil if token.strip.empty?

    user = UserQuery.new.password_reset_token_hash(digest(token)).first?
    return nil unless user
    return nil unless token_valid?(user)

    user
  end

  def self.clear(user : User) : User
    SavePasswordReset.update!(
      user,
      password_reset_token_hash: nil,
      password_reset_sent_at: nil,
    )
  end

  # Time left before another letter may be sent, or nil when sending is fine.
  def self.resend_in(user : User) : Time::Span?
    sent_at = user.password_reset_sent_at
    return nil unless sent_at

    elapsed = Time.utc - sent_at
    return nil if elapsed >= AppSettings::PASSWORD_RESET_RESEND_INTERVAL

    AppSettings::PASSWORD_RESET_RESEND_INTERVAL - elapsed
  end

  def self.token_valid?(user : User) : Bool
    sent_at = user.password_reset_sent_at
    return false unless sent_at

    sent_at >= AppSettings::PASSWORD_RESET_TTL.ago
  end

  def self.digest(token : String) : String
    Digest::SHA256.hexdigest(token)
  end
end
