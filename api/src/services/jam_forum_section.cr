# Every published jam gets its own forum category under the root "Джемы".
# Drafts have no section, so a jam does not leak before its organizer publishes
# it. The root is created lazily: a deployment that already has forum sections
# never runs the seed again.
module JamForumSection
  ROOT_SLUG       = "jams"
  TITLE_MAX       =  80
  DESCRIPTION_MAX = 200

  def self.ensure_root : ForumSection
    existing = ForumSectionQuery.new.by_slug(ROOT_SLUG).first?
    return existing if existing

    SaveForumSection.create!(
      title: "Джемы",
      slug: ROOT_SLUG,
      description: "Игровые джемы и конкурсы.",
      group_title: "Сообщество",
      ai_answers_enabled: false,
    )
  end

  def self.create_for(jam : Jam) : ForumSection
    if id = jam.forum_section_id
      if existing = ForumSectionQuery.new.id(id).first?
        return existing
      end
    end

    root = ensure_root
    description = section_description(jam)

    SaveForumSection.create!(
      title: section_title(jam),
      slug: Slugify.unique_forum_section_slug("jam-#{jam.slug}"),
      description: description,
      parent_id: root.id,
      ai_answers_enabled: false,
    )
  end

  # The section title follows the jam title; the slug stays stable so links and
  # topics do not move. The section may have topics by then.
  def self.sync_title(jam : Jam) : Nil
    id = jam.forum_section_id
    return unless id

    section = ForumSectionQuery.new.id(id).first?
    return unless section

    title = section_title(jam)
    return if section.title == title

    SaveForumSection.update!(section, title: title)
  end

  private def self.section_title(jam : Jam) : String
    jam.title[0, TITLE_MAX].strip
  end

  private def self.section_description(jam : Jam) : String
    text = jam.tagline.to_s.strip
    text = jam.description.to_s if text.empty?
    description = FeedText.excerpt(text, DESCRIPTION_MAX)
    description.empty? ? "Обсуждение джема «#{jam.title}»" : description
  end
end
