class Api::V1::Feeds::Projects < Api::V1::FeedAction
  get "/api/v1/feeds/projects" do
    projects = ProjectQuery.new
      .visible_to(nil)
      .newest
      .id.desc_order
      .preload_user
      .preload_tags
      .limit(ITEMS_LIMIT)
      .results

    render_feed RssFeed.new(
      title: "#{AppSettings::SITE_NAME} — новые проекты",
      link: absolute_url("/"),
      description: "Новые проекты в каталоге #{AppSettings::SITE_NAME}",
      self_url: self_url,
      items: projects.map { |project| project_item(project) },
    )
  end
end
