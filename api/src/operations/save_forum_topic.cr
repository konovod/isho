class SaveForumTopic < ForumTopic::SaveOperation
  permit_columns title

  before_save do
    title.value = title.value.to_s.strip

    validate_required title
    validate_size_of title, max: AppSettings::FORUM_TOPIC_TITLE_MAX

    if slug.value.to_s.empty?
      section = section_id.value.not_nil!
      slug.value = Slugify.unique_forum_topic_slug(section, title.value.to_s)
    end
  end
end
