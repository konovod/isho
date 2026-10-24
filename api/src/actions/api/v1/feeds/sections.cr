class Api::V1::Feeds::Sections < Api::V1::FeedAction
  include Api::V1::Forum::Lookup

  get "/api/v1/feeds/forum/:section_slug" do
    section = find_forum_section!(params.get(:section_slug))

    query = ForumTopicQuery.new
      .for_section(section.id)
      .created_at.desc_order
      .id.desc_order
    query = query.with_visible_project(nil) if section.slug == "projects"

    topics = query
      .preload_user
      .limit(ITEMS_LIMIT)
      .results

    first_posts = ForumPostQuery.new.first_for_topics(topics.map(&.id)).results
    bodies = first_posts.to_h { |post| {post.topic_id, post.body} }

    items = topics.map do |topic|
      description = FeedText.excerpt(bodies[topic.id]?)
      description = "Новая тема от #{topic.user.name}" if description.empty?

      RssFeed::Item.new(
        title: topic.title,
        link: absolute_url("/forum/#{section.slug}/#{topic.slug}"),
        guid: "isho:forum_topic:#{topic.id}",
        published_at: topic.created_at,
        creator: topic.user.name,
        description: description,
      )
    end

    section_description = FeedText.excerpt(section.description, 300)
    section_description = "Новые темы в разделе «#{section.title}»" if section_description.empty?

    render_feed RssFeed.new(
      title: "#{AppSettings::SITE_NAME} — новые темы в разделе «#{section.title}»",
      link: absolute_url("/forum/#{section.slug}"),
      description: section_description,
      self_url: self_url,
      items: items,
    )
  end
end
