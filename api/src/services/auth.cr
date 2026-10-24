require "digest/sha256"
require "random/secure"

module Auth
  # An admin viewing the site as another account. The target's session is
  # short-lived, and `Api::Auth::Helpers` only honours it next to the admin's
  # own session cookie.
  struct Impersonation
    getter session : AuthSession
    getter admin : User
    getter user : User

    def initialize(@session : AuthSession, @admin : User, @user : User)
    end
  end

  # Opaque, database-backed sessions. The raw token only exists in the cookie;
  # the database stores a SHA-256 digest so a database leak cannot be replayed.
  module Session
    TOKEN_BYTES = 32

    def self.start(
      user : User,
      user_agent : String? = nil,
      ip : String? = nil,
      ttl : Time::Span = AppSettings::SESSION_TTL,
      impersonator_id : Int64? = nil,
    ) : {AuthSession, String}
      token = Random::Secure.urlsafe_base64(TOKEN_BYTES)
      session = AuthSession::SaveOperation.create!(
        user_id: user.id,
        token_hash: digest(token),
        expires_at: ttl.from_now,
        user_agent: user_agent,
        ip: ip,
        impersonator_id: impersonator_id,
      )
      {session, token}
    end

    # Only ordinary sessions count here: an impersonation token belongs to the
    # second cookie and must not work on its own.
    def self.user_for(token : String) : User?
      return nil if token.empty?

      AuthSessionQuery.new
        .token_hash(digest(token))
        .active
        .where("impersonator_id IS NULL")
        .preload_user
        .first?
        .try(&.user)
    end

    # The target's session for an admin, valid only for that same admin.
    def self.impersonation_for(token : String, admin_id : Int64) : AuthSession?
      return nil if token.empty?

      AuthSessionQuery.new
        .token_hash(digest(token))
        .active
        .where("impersonator_id = ?", admin_id)
        .preload_user
        .first?
    end

    def self.destroy(token : String) : Nil
      return if token.empty?
      AuthSessionQuery.new.token_hash(digest(token)).delete
    end

    # Used when the password changes: every device has to sign in again.
    def self.destroy_all(user : User) : Nil
      AuthSessionQuery.new.user_id(user.id).delete
    end

    def self.digest(token : String) : String
      Digest::SHA256.hexdigest(token)
    end
  end
end
