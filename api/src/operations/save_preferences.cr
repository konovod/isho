class SavePreferences < User::SaveOperation
  permit_columns show_nsfw, max_ai_usage, ai_flair_enabled

  before_save do
    normalize
    validate_ai_usage
  end

  private def normalize
    show_nsfw.value = true if show_nsfw.value.nil?
    max_ai_usage.value = "full" if max_ai_usage.value.to_s.strip.empty?
  end

  private def validate_ai_usage
    value = max_ai_usage.value.to_s.strip.downcase
    max_ai_usage.value = value

    unless AppSettings.valid_ai_usage?(value)
      max_ai_usage.add_error "must be ai_free, partial, significant or full"
    end
  end
end
