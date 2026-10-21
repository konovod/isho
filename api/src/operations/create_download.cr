class CreateDownload < Download::SaveOperation
  permit_columns label, url, platform, version

  before_save do
    normalize
    validate_required label, url
    validate_size_of label, max: 80
    validate_size_of platform, max: 40
    validate_size_of version, max: 40
    validate_external_url
  end

  private def normalize
    label.value = label.value.to_s.strip
    url.value = url.value.to_s.strip
    platform.value = platform.value.to_s.strip
    version.value = version.value.to_s.strip
  end

  private def validate_external_url
    value = url.value.to_s

    if value.size > AppSettings::MAX_EXTERNAL_URL_SIZE
      url.add_error "is too long"
      return
    end

    uri = begin
      URI.parse(value)
    rescue URI::Error
      nil
    end

    unless uri && uri.scheme == "https" && !uri.host.to_s.empty? && uri.user.nil? && uri.password.nil?
      url.add_error "must be a public https:// link"
      return
    end

    if internal_host?(uri.host.to_s)
      url.add_error "must not point to a local address"
    end
  end

  private def internal_host?(host : String) : Bool
    host = host.downcase

    host == "localhost" ||
      host == "127.0.0.1" ||
      host == "::1" ||
      host.starts_with?("10.") ||
      host.starts_with?("192.168.") ||
      host.matches?(/\A172\.(1[6-9]|2\d|3[01])\./)
  end
end
