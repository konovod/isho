# Sections are edited from the moderation panel. A slug is part of the section
# URL (/forum/:slug), so it can only change while the section is empty and never
# for "projects" — project discussions look that section up by slug.
#
# On update Avram starts every attribute from the stored record, so fields
# missing from a PATCH keep their value. An empty optional string arrives as nil
# and clears the column.
class SaveForumSection < ForumSection::SaveOperation
  permit_columns title, slug, description, group_title, position, ai_answers_enabled

  MAX_TITLE_LENGTH       =  80
  MAX_DESCRIPTION_LENGTH = 200
  MAX_GROUP_TITLE_LENGTH =  60
  MAX_SLUG_LENGTH        =  80

  before_save do
    normalize

    validate_required title
    validate_size_of title, max: MAX_TITLE_LENGTH
    validate_size_of description, max: MAX_DESCRIPTION_LENGTH
    validate_size_of group_title, max: MAX_GROUP_TITLE_LENGTH
    validate_size_of slug, max: MAX_SLUG_LENGTH
    validate_uniqueness_of slug
    validate_slug_lock
  end

  private def normalize
    title.value = title.value.to_s.strip
    normalize_slug

    description.value = blank_to_nil(description.value)
    group_title.value = blank_to_nil(group_title.value)
    position.value = record.try(&.position) || next_position if position.value.nil?
    ai_answers_enabled.value = true if ai_answers_enabled.value.nil?
    # Project discussions never get an AI opening answer.
    ai_answers_enabled.value = false if slug.value == "projects"
  end

  # A new section gets a slug from its title, an edited one keeps the stored
  # slug unless a different value was sent. Either way the slug is ASCII and
  # URL-safe, so a Cyrillic title or a copy-pasted address still works.
  private def normalize_slug
    existing = record.try(&.slug)
    submitted = slug.value.to_s.strip

    if existing && (submitted.empty? || submitted == existing)
      slug.value = existing
    elsif submitted.empty?
      slug.value = Slugify.unique_forum_section_slug(title.value.to_s)
    else
      normalized = Slugify.call(submitted, "")
      slug.value = normalized.empty? ? Slugify.unique_forum_section_slug(title.value.to_s) : normalized
    end
  end

  private def blank_to_nil(value : String?) : String?
    text = value.to_s.strip
    text.empty? ? nil : text
  end

  private def next_position : Int32
    last = ForumSectionQuery.new.position.desc_order.first?
    (last.try(&.position) || 0) + 10
  end

  private def validate_slug_lock
    existing = record
    return unless existing
    return if slug.value == existing.slug
    return if existing.slug != "projects" && ForumTopicQuery.new.section_id(existing.id).select_count.zero?

    slug.add_error "can not be changed for a section with topics"
  end
end
