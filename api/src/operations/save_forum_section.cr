# Sections are edited from the moderation panel. A slug is part of the section
# URL (/forum/:slug), so it can only change while the section is empty and never
# for the protected roots — project discussions and jams look those up by slug.
#
# Sections form a two-level tree. A child section belongs to a root section and
# ignores group_title; the parent provides the grouping and the breadcrumb. The
# URL stays flat, so the hierarchy never changes an existing address.
#
# On update Avram starts every attribute from the stored record, so fields
# missing from a PATCH keep their value. An empty optional string arrives as nil
# and clears the column.
class SaveForumSection < ForumSection::SaveOperation
  permit_columns title, slug, description, group_title, position, ai_answers_enabled, parent_id

  MAX_TITLE_LENGTH       =  80
  MAX_DESCRIPTION_LENGTH = 200
  MAX_GROUP_TITLE_LENGTH =  60
  MAX_SLUG_LENGTH        =  80

  # These sections are roots for the rest of the app and cannot be moved.
  PROTECTED_ROOT_SLUGS = %w[projects jams]

  before_save do
    normalize

    validate_required title
    validate_size_of title, max: MAX_TITLE_LENGTH
    validate_size_of description, max: MAX_DESCRIPTION_LENGTH
    validate_size_of group_title, max: MAX_GROUP_TITLE_LENGTH
    validate_size_of slug, max: MAX_SLUG_LENGTH
    validate_uniqueness_of slug
    validate_parent
    validate_protected_root
    validate_slug_lock
  end

  private def normalize
    title.value = title.value.to_s.strip
    normalize_slug

    description.value = blank_to_nil(description.value)
    group_title.value = blank_to_nil(group_title.value)
    # A subsection is always shown under its parent, so the visual group label
    # only belongs to roots.
    group_title.value = nil if parent_id.value
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

  # Siblings share a position scale. A new child starts after the last child of
  # its parent, not after the last section on the whole forum.
  private def next_position : Int32
    query = ForumSectionQuery.new
    query = parent_id.value ? query.children_of(parent_id.value.not_nil!) : query.roots
    last = query.position.desc_order.first?
    (last.try(&.position) || 0) + 10
  end

  private def validate_parent
    value = parent_id.value
    return if value.nil?

    parent = ForumSectionQuery.new.id(value).first?
    unless parent
      parent_id.add_error "does not exist"
      return
    end

    if record.try(&.id) == parent.id
      parent_id.add_error "can not point to itself"
      return
    end

    unless parent.root?
      parent_id.add_error "must be a root section"
      return
    end

    # A root with children cannot become a child: that would create a third
    # level, which the public UI and breadcrumbs do not support.
    if existing = record
      if ForumSectionQuery.new.children_of(existing.id).first?
        parent_id.add_error "can not be added to a section with subsections"
      end
    end
  end

  private def validate_protected_root
    value = parent_id.value
    return if value.nil?

    existing = record
    if existing
      parent_id.add_error "can not be changed for a protected section" if PROTECTED_ROOT_SLUGS.includes?(existing.slug)
    elsif PROTECTED_ROOT_SLUGS.includes?(slug.value.to_s)
      parent_id.add_error "can not be changed for a protected section"
    end
  end

  private def validate_slug_lock
    existing = record
    return unless existing
    return if slug.value == existing.slug
    return if !PROTECTED_ROOT_SLUGS.includes?(existing.slug) && !has_topics?(existing) && !has_children?(existing)

    slug.add_error "can not be changed for a section with topics or subsections"
  end

  private def has_topics?(section : ForumSection) : Bool
    !ForumTopicQuery.new.section_id(section.id).select_count.zero?
  end

  private def has_children?(section : ForumSection) : Bool
    !ForumSectionQuery.new.children_of(section.id).select_count.zero?
  end
end
