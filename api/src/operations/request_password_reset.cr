class RequestPasswordReset < Avram::Operation
  param_key :user

  # You can modify this in src/operations/mixins/user_from_email.cr
  include UserFromEmail

  attribute email : String

  # Runs validations and yields the user when the address matches an account.
  # An unknown address is not an error: the action answers the same way for
  # everyone, so the endpoint cannot be used to enumerate accounts.
  def run
    email.value = email.value.to_s.strip.downcase
    validate_required email

    valid? ? user_from_email : nil
  end
end
