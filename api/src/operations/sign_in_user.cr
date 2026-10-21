class SignInUser < Avram::Operation
  param_key :user
  include UserFromEmail

  attribute email : String
  attribute password : String

  def run
    email.value = email.value.to_s.strip.downcase
    user = user_from_email
    validate_credentials(user)

    valid? ? user : nil
  end

  private def validate_credentials(user)
    if user
      unless Authentic.correct_password?(user, password.value.to_s)
        password.add_error "is wrong"
      end
    else
      email.add_error "is not in our system"
    end
  end
end
