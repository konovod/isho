class SignInUser < Avram::Operation
  param_key :user

  # `login` accepts an email or a username. `email` is kept for older clients
  # and is used only when `login` is missing.
  attribute login : String
  attribute email : String
  attribute password : String

  def run
    login.value = credential
    user = user_from_login
    validate_credentials(user)

    valid? ? user : nil
  end

  private def credential : String
    value = login.value.to_s.strip
    value = email.value.to_s.strip if value.empty?
    value.downcase
  end

  private def user_from_login : User?
    value = login.value.to_s
    return nil if value.empty?

    UserQuery.new.by_login(value).first?
  end

  # A single message on the same field for an unknown login and a wrong
  # password: otherwise the response would reveal which emails and usernames
  # exist.
  private def validate_credentials(user)
    if user
      unless Authentic.correct_password?(user, password.value.to_s)
        login.add_error "is invalid"
      end
    else
      login.add_error "is invalid"
    end
  end
end
