class BlockEmail < BlockedEmail::SaveOperation
  permit_columns email, username

  before_save do
    email.value = email.value.to_s.strip.downcase

    name = username.value.to_s.strip
    username.value = name.empty? ? nil : name

    validate_required email
  end
end
