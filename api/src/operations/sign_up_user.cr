class SignUpUser < User::SaveOperation
  param_key :user
  include PasswordValidations

  permit_columns email, username, display_name
  attribute password : String
  attribute password_confirmation : String

  before_save do
    normalize
    validate_username
    validate_uniqueness_of email
    validate_uniqueness_of username
    Authentic.copy_and_encrypt(password, to: encrypted_password) if password.valid?
  end

  private def normalize
    email.value = email.value.to_s.strip.downcase
    username.value = username.value.to_s.strip.downcase
    is_admin.value = false if is_admin.value.nil?

    name = display_name.value.to_s.strip
    display_name.value = name.empty? ? nil : name
  end

  private def validate_username
    value = username.value.to_s

    if value.empty?
      username.add_error "is required"
    elsif !value.matches?(/\A[a-z0-9_]{3,32}\z/)
      username.add_error "must be 3-32 characters using a-z, 0-9 or _"
    elsif AppSettings::RESERVED_USERNAMES.includes?(value)
      username.add_error "is reserved"
    end
  end
end
