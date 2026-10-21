class User < BaseModel
  include Carbon::Emailable
  include Authentic::PasswordAuthenticatable

  table do
    column email : String
    column username : String
    column display_name : String?
    column bio : String?
    column encrypted_password : String
    column is_admin : Bool
    has_many projects : Project
    has_many auth_sessions : AuthSession
  end

  def emailable : Carbon::Address
    Carbon::Address.new(email)
  end

  def name : String
    display_name || username
  end
end
