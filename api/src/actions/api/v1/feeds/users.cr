class Api::V1::Feeds::Users < Api::V1::FeedAction
  get "/api/v1/feeds/users/:username" do
    username = params.get(:username)
    user = UserQuery.new.by_username(username).first? ||
           raise Avram::RecordNotFoundError.new(User.table_name, username)

    projects = ProjectQuery.new
      .visible_to(nil)
      .for_user(user.id)
      .newest
      .id.desc_order
      .preload_user
      .preload_tags
      .limit(ITEMS_LIMIT)
      .results

    render_feed RssFeed.new(
      title: "#{AppSettings::SITE_NAME} — проекты #{user.name}",
      link: absolute_url("/u/#{user.username}"),
      description: "Новые проекты автора #{user.name}",
      self_url: self_url,
      items: projects.map { |project| project_item(project) },
    )
  end
end
