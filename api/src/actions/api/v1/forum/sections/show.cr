class Api::V1::Forum::Sections::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Forum::Blocks
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
      .preload_section(ForumSectionQuery.new.preload_parent)
      .preload_project
      .preload_last_post_user

    query = query.with_visible_project(current_user?) if section.slug == "projects"
    if forum_blocks? && (blocker = current_user?)
      query = query.excluding_blocked_authors(blocker.id)
    end

    total = query.clone.select_count
    topics = query
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    read_counts = forum_read_counts(topics)
    states = if forum_blocks? && (viewer = current_user?)
               ForumReadState.for_topics(topics.map(&.id), viewer.id)
             else
               {} of Int64 => ForumReadState::State
             end
    children = ForumSectionQuery.new.children_of(section.id).ordered.preload_parent.results

    json({
      section:  ForumSectionSerializer.new(section, current_user?, forum_blocked_ids),
      children: children.map { |child| ForumSectionSerializer.new(child, current_user?, forum_blocked_ids) },
      items:    topics.map { |topic|
        ForumTopicSerializer.new(
          topic,
          read_counts.try { |counts| counts[topic.id]? },
          state: states[topic.id]?,
          blocked_user_ids: forum_blocked_ids,
        )
      },
      meta: pagination_meta(page, per_page, total),
    })
  end
end
