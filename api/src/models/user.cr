class User < BaseModel
  include Carbon::Emailable
  include Authentic::PasswordAuthenticatable

  table do
    column email : String
    column username : String
    column display_name : String?
    column bio : String?
    column theme : String
    column encrypted_password : String
    column is_admin : Bool
    column email_confirmed_at : Time?
    column email_confirmation_token_hash : String?
    column email_confirmation_sent_at : Time?
    has_many projects : Project
    has_many auth_sessions : AuthSession
    has_many forum_topics : ForumTopic
    has_many forum_posts : ForumPost
  end

  def emailable : Carbon::Address
    Carbon::Address.new(email)
  end

  def name : String
    display_name || username
  end

  # Only admins moderate for now; the separate moderator role can be added later.
  def moderator? : Bool
    is_admin
  end

  def email_confirmed? : Bool
    !email_confirmed_at.nil?
  end
end
