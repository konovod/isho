class PasswordResetEmail < BaseEmail
  templates text, html

  def initialize(@user : User, @token : String)
  end

  to @user
  from default_from
  subject "Сброс пароля в isho"

  def user : User
    @user
  end

  def reset_url : String
    "#{AppSettings.public_origin}/reset_password?token=#{@token}"
  end
end
