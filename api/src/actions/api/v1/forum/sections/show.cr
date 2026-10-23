class Api::V1::Forum::Sections::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::ReadState

  get "/api/v1/forum/sections/:section_slug" do
    section = find_forum_section!(params.get(:section_slug))
    page = current_page
    per_page = page_size(AppSettings::FORUM_TOPICS_PER_PAGE, 50)

    query = ForumTopicQuery.new
      .for_section(section.id)
      .newest_activity
      .preload_user
      .preload_section
      .preload_project
      .preload_last_post_user

    query = query.with_visible_project(current_user?) if section.slug == "projects"

    total = query.clone.select_count
    topics = query
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    read_counts = forum_read_counts(topics)

    json({
      section: ForumSectionSerializer.new(section, current_user?),
      items:   topics.map { |topic| ForumTopicSerializer.new(topic, read_counts.try { |counts| counts[topic.id]? }) },
      meta:    pagination_meta(page, per_page, total),
    })
  end
end
