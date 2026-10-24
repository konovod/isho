class Api::V1::Feeds::Topics < Api::V1::FeedAction
  include Api::V1::Forum::Lookup
  include Api::V1::Forum::Visibility

  get "/api/v1/feeds/forum/:section_slug/:topic_slug" do
    section = find_forum_section!(params.get(:section_slug))
    topic = find_forum_topic!(section, params.get(:topic_slug))
    require_visible_forum_topic_to_guest!(topic)

    total = ForumPostQuery.new.for_topic(topic.id).select_count
    posts = ForumPostQuery.new
      .for_topic(topic.id)
      .newest_first
      .id.desc_order
      .preload_user
      .limit(ITEMS_LIMIT)
      .results

    path = "/forum/#{section.slug}/#{topic.slug}"

    items = posts.each_with_index.map do |post, index|
      position = total - index
      page = (position - 1) // AppSettings::FORUM_POSTS_PER_PAGE + 1
      link = page > 1 ? "#{path}?page=#{page}#post-#{post.id}" : "#{path}#post-#{post.id}"

      description = FeedText.excerpt(post.body)
      description = "Сообщение от #{post.user.name}" if description.empty?

      RssFeed::Item.new(
        title: position == 1 ? topic.title : "Re: #{topic.title}",
        link: absolute_url(link),
        guid: "isho:forum_post:#{post.id}",
        published_at: post.created_at,
        creator: post.user.name,
        description: description,
      )
    end.to_a

    render_feed RssFeed.new(
      title: "#{AppSettings::SITE_NAME} — сообщения темы «#{topic.title}»",
      link: absolute_url(path),
      description: "Новые сообщения темы «#{topic.title}»",
      self_url: self_url,
      items: items,
    )
  end

  private def require_visible_forum_topic_to_guest!(topic : ForumTopic) : Nil
    return if forum_topic_visible_to?(topic, nil)

    raise Avram::RecordNotFoundError.new(ForumTopic.table_name, topic.slug)
  end
end
