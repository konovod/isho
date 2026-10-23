class SaveUploadSession < UploadSession::SaveOperation
  param_key :upload

  permit_columns kind, filename, total_bytes

  before_save do
    kind.value = kind.value.to_s.strip.downcase
    filename.value = BuildStorage.safe_filename(filename.value.to_s)
  end
end
