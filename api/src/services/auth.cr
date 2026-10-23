require "digest/sha256"
require "random/secure"

module Auth
  # Opaque, database-backed sessions. The raw token only exists in the cookie;
  # the database stores a SHA-256 digest so a database leak cannot be replayed.
  module Session
    TOKEN_BYTES = 32

    def self.start(user : User, user_agent : String? = nil, ip : String? = nil) : {AuthSession, String}
      token = Random::Secure.urlsafe_base64(TOKEN_BYTES)
      session = AuthSession::SaveOperation.create!(
        user_id: user.id,
        token_hash: digest(token),
        expires_at: AppSettings::SESSION_TTL.from_now,
        user_agent: user_agent,
        ip: ip,
      )
      {session, token}
    end

    def self.user_for(token : String) : User?
      return nil if token.empty?

      AuthSessionQuery.new
        .token_hash(digest(token))
        .active
        .preload_user
        .first?
        .try(&.user)
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
