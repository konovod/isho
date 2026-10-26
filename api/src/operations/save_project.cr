class SaveProject < Project::SaveOperation
  permit_columns kind, dev_status, genre, title, tagline, description, nsfw, ai_usage

  before_save do
    normalize
    validate_required title
    validate_size_of title, max: 120
    validate_size_of tagline, max: 160
    validate_size_of description, max: 20_000
    validate_kind
    validate_dev_status
    validate_genre
    validate_ai_usage

    if slug.value.to_s.empty?
      slug.value = Slugify.unique_project_slug(title.value.to_s)
    end
  end

  private def normalize
    title.value = title.value.to_s.strip
    tagline.value = tagline.value.to_s.strip
    description.value = description.value.to_s.strip
    kind.value = kind.value.to_s.strip.downcase
    kind.value = "game" if kind.value.to_s.empty?
    dev_status.value = dev_status.value.to_s.strip.downcase
    dev_status.value = "active" if dev_status.value.to_s.empty?
    status.value = "draft" if status.value.to_s.strip.empty?
    nsfw.value = false if nsfw.value.nil?
    ai_usage.value = "ai_free" if ai_usage.value.to_s.strip.empty?

    genre.value = genre.value.to_s.strip.downcase
    genre.value = nil if genre.value.to_s.empty?
    # Only games have a genre; switching a project to a tool or an asset must
    # not leave a stale value that the catalogue could filter by.
    genre.value = nil unless kind.value.to_s == "game"
  end

  private def validate_ai_usage
    value = ai_usage.value.to_s.strip.downcase
    ai_usage.value = value

    unless AppSettings.valid_ai_usage?(value)
      ai_usage.add_error "must be ai_free, partial, significant or full"
    end
  end

  private def validate_kind
    unless AppSettings::PROJECT_KINDS.includes?(kind.value.to_s)
      kind.add_error "must be game, tool or asset"
    end
  end

  private def validate_dev_status
    unless AppSettings::PROJECT_DEV_STATUSES.includes?(dev_status.value.to_s)
      dev_status.add_error "must be alpha, beta, active, completed or contest"
    end
  end

  private def validate_genre
    value = genre.value
    return if value.nil?

    unless AppSettings::PROJECT_GENRES.includes?(value)
      genre.add_error "is not a known genre"
    end
  end
end
