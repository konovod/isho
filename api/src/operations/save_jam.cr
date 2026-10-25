class SaveJam < Jam::SaveOperation
  permit_columns title, slug, tagline, description, rules, prizes, theme, results_note,
    starts_at, submissions_close_at, voting_closes_at, time_zone,
    judging_mode, score_scale

  before_save do
    normalize

    validate_required title
    validate_size_of title, max: AppSettings::JAM_TITLE_MAX
    validate_size_of tagline, max: AppSettings::JAM_TAGLINE_MAX
    validate_size_of theme, max: AppSettings::JAM_THEME_MAX
    validate_size_of description, max: AppSettings::JAM_TEXT_MAX
    validate_size_of rules, max: AppSettings::JAM_TEXT_MAX
    validate_size_of prizes, max: AppSettings::JAM_TEXT_MAX
    validate_size_of results_note, max: AppSettings::JAM_RESULTS_NOTE_MAX
    validate_uniqueness_of slug
    validate_slug_lock
    validate_dates
    validate_time_zone
    validate_judging_mode
    validate_score_scale
    validate_scoring_lock
  end

  after_save do |jam|
    # The forum section follows the title until the jam is deleted. It is
    # created on publish, so a draft simply has nothing to update.
    JamForumSection.sync_title(jam)
  end

  private def normalize
    title.value = title.value.to_s.strip
    normalize_slug

    tagline.value = blank_to_nil(tagline.value)
    description.value = blank_to_nil(description.value)
    rules.value = blank_to_nil(rules.value)
    prizes.value = blank_to_nil(prizes.value)
    theme.value = blank_to_nil(theme.value)
    results_note.value = blank_to_nil(results_note.value)

    time_zone.value = "Europe/Moscow" if time_zone.value.to_s.strip.empty?
    time_zone.value = time_zone.value.to_s.strip
    status.value = "draft" if status.value.to_s.strip.empty?
    judging_mode.value = "community" if judging_mode.value.to_s.strip.empty?
    judging_mode.value = judging_mode.value.to_s.strip.downcase
    score_scale.value = 5 if score_scale.value.nil?
  end

  private def normalize_slug
    existing = record.try(&.slug)
    submitted = slug.value.to_s.strip

    if existing && (submitted.empty? || submitted == existing)
      slug.value = existing
    elsif submitted.empty?
      slug.value = Slugify.unique_jam_slug(title.value.to_s)
    else
      normalized = Slugify.call(submitted, "")
      slug.value = normalized.empty? ? Slugify.unique_jam_slug(title.value.to_s) : normalized
    end
  end

  private def blank_to_nil(value : String?) : String?
    text = value.to_s.strip
    text.empty? ? nil : text
  end

  private def validate_slug_lock
    existing = record
    return unless existing
    return if slug.value == existing.slug
    return if existing.draft?

    slug.add_error "can not be changed after publication"
  end

  private def validate_dates
    starts = starts_at.value
    submissions = submissions_close_at.value
    voting = voting_closes_at.value

    if starts && submissions && starts >= submissions
      submissions_close_at.add_error "must be after the start"
    end

    if submissions && voting && submissions >= voting
      voting_closes_at.add_error "must be after submissions close"
    end
  end

  private def validate_time_zone
    value = time_zone.value.to_s
    return if value.empty?

    begin
      Time::Location.load(value)
    rescue
      time_zone.add_error "is not a known time zone"
    end
  end

  private def validate_judging_mode
    unless AppSettings::JAM_JUDGING_MODES.includes?(judging_mode.value.to_s)
      judging_mode.add_error "must be community or participants"
    end
  end

  private def validate_score_scale
    value = score_scale.value || 5
    unless AppSettings::JAM_SCORE_SCALES.includes?(value)
      score_scale.add_error "must be 5 or 10"
    end
  end

  # Once the first scorecard exists, changing the counting mode, the scale or
  # the judging window would silently rewrite the results.
  private def validate_scoring_lock
    existing = record
    return unless existing
    return unless JamScoring.locked?(existing)

    if judging_mode.value.to_s != existing.judging_mode
      judging_mode.add_error "can not be changed after scoring starts"
    end

    if (score_scale.value || 5) != existing.score_scale
      score_scale.add_error "can not be changed after scoring starts"
    end

    if starts_at.value != existing.starts_at
      starts_at.add_error "can not be changed after scoring starts"
    end

    if submissions_close_at.value != existing.submissions_close_at
      submissions_close_at.add_error "can not be changed after scoring starts"
    end

    if voting_closes_at.value != existing.voting_closes_at
      voting_closes_at.add_error "can not be changed after scoring starts"
    end
  end
end
