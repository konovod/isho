class SaveProject < Project::SaveOperation
  permit_columns kind, title, tagline, description, nsfw, ai_usage

  before_save do
    normalize
    validate_required title
    validate_size_of title, max: 120
    validate_size_of tagline, max: 160
    validate_size_of description, max: 20_000
    validate_kind
    validate_ai_usage

    if slug.value.to_s.empty?
      slug.value = Slugify.unique_project_slug(title.value.to_s)
    end
  end

  private def normalize
    title.value = title.value.to_s.strip
    tagline.value = tagline.value.to_s.strip
    description.value = description.value.to_s.strip
    kind.value = "game" if kind.value.to_s.strip.empty?
    status.value = "draft" if status.value.to_s.strip.empty?
    nsfw.value = false if nsfw.value.nil?
    ai_usage.value = "ai_free" if ai_usage.value.to_s.strip.empty?
  end

  private def validate_ai_usage
    value = ai_usage.value.to_s.strip.downcase
    ai_usage.value = value

    unless AppSettings.valid_ai_usage?(value)
      ai_usage.add_error "must be ai_free, partial, significant or full"
    end
  end

  private def validate_kind
    unless %w[game tool asset].includes?(kind.value.to_s)
      kind.add_error "must be game, tool or asset"
    end
  end
end
