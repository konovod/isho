class EmailConfirmationEmail < BaseEmail
  templates text, html

  def initialize(@user : User, @token : String)
  end

  to @user
  from default_from
  subject "Подтвердите почту в isho"

  def user : User
    @user
  end

  def confirmation_url : String
    "#{AppSettings.public_origin}/confirm_email?token=#{@token}"
  end
end
