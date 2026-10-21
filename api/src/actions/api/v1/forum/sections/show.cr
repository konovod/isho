class Api::V1::Forum::Sections::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup

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

    query = query.with_published_project if section.slug == "projects"

    total = query.clone.select_count
    topics = query
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    json({
      section: ForumSectionSerializer.new(section),
      items:   topics.map { |topic| ForumTopicSerializer.new(topic) },
      meta:    pagination_meta(page, per_page, total),
    })
  end
end
