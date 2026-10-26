class SavePrivateMessage < PrivateMessage::SaveOperation
  permit_columns body

  before_save do
    body.value = body.value.to_s.strip

    validate_required body
    validate_size_of body, max: AppSettings::PRIVATE_MESSAGE_MAX_CHARS
  end
end
