class SaveBuild < Build::SaveOperation
  param_key :build

  attach stored_file
  permit_columns label, platform, version

  before_save do
    normalize
    validate_kind
    validate_payload
  end

  private def normalize
    label.value = label.value.to_s.strip
    label.value = "Скачать" if label.value.to_s.empty?
    platform.value = platform.value.to_s.strip.presence
    version.value = version.value.to_s.strip.presence
  end

  private def validate_kind
    unless %w[file web].includes?(kind.value.to_s)
      kind.add_error "must be file or web"
    end
  end

  private def validate_payload
    validate_size_of label, max: 80
    validate_size_of platform, max: 40
    validate_size_of version, max: 40

    if (size_bytes.value || 0_i64) <= 0
      size_bytes.add_error "must be greater than 0"
    end

    if kind.value.to_s == "web"
      if entry_path.value.to_s.strip.empty?
        entry_path.add_error "is required for a web build"
      end
    else
      if stored_file.value.nil?
        stored_file.add_error "is required for a downloadable build"
      end
      if entry_path.value.to_s.strip.present?
        entry_path.add_error "is only used by web builds"
      end
    end
  end
end
