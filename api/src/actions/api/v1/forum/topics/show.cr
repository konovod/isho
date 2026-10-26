class Api::V1::Forum::Topics::Show < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Forum::Params
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Visibility
  include Api::V1::Forum::ReadState

  get "/api/v1/forum/sections/:section_slug/topics/:topic_slug" do
    section = find_forum_section!(params.get(:section_slug))
    topic = find_forum_topic!(section, params.get(:topic_slug))
    require_visible_forum_topic!(topic)

    page = current_page
    per_page = page_size(AppSettings::FORUM_POSTS_PER_PAGE, 50)

    query = ForumPostQuery.new.for_topic(topic.id).chronological
    blocker_id = forum_blocks? ? current_user?.try(&.id) : nil
    query = query.excluding_blocked_authors(blocker_id) if blocker_id

    total = query.clone.select_count
    posts = query
      .preload_user
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    quote_pages = {} of Int64 => Int32?
    posts.each do |post|
      quoted_id = post.quoted_post_id
      next unless quoted_id
      next if quote_pages.has_key?(quoted_id)

      quote_pages[quoted_id] = forum_quote_page(post, blocker_id)
    end

    reactions = ForumReactions.summaries(posts.map(&.id), current_user?.try(&.id))

    states = if forum_blocks? && (viewer = current_user?)
               ForumReadState.for_topics([topic.id], viewer.id)
             else
               {} of Int64 => ForumReadState::State
             end

    json({
      topic: ForumTopicSerializer.new(
        topic,
        forum_read_count(topic),
        page == 1 ? ForumAiAnswerQuery.new.for_topic(topic.id).first? : nil,
        state: states[topic.id]?,
        blocked_user_ids: forum_blocked_ids,
      ),
      items: posts.map { |post|
        ForumPostSerializer.new(
          post,
          post.quoted_post_id.try { |id| quote_pages[id]? },
          reactions[post.id]? || ForumReactions::Summary.empty,
          forum_blocked_usernames,
        )
      },
      meta: pagination_meta(page, per_page, total),
    })
  end
end
