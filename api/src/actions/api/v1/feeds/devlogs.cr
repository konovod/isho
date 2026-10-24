class Api::V1::Feeds::Devlogs < Api::V1::FeedAction
  get "/api/v1/feeds/projects/:slug/devlogs" do
    slug = params.get(:slug)
    project = ProjectQuery.new.slug(slug).preload_user.first? ||
              raise Avram::RecordNotFoundError.new(Project.table_name, slug)

    unless project.published? && project.content_visible_to?(nil)
      raise Avram::RecordNotFoundError.new(Project.table_name, slug)
    end

    devlogs = DevlogQuery.new
      .project_id(project.id)
      .newest
      .id.desc_order
      .limit(ITEMS_LIMIT)
      .results

    items = devlogs.map do |devlog|
      description = FeedText.excerpt(devlog.body)
      description = "Запись дневника проекта «#{project.title}»" if description.empty?

      RssFeed::Item.new(
        title: devlog.title,
        link: absolute_url("/p/#{project.slug}/devlog/#{devlog.slug}"),
        guid: "isho:devlog:#{devlog.id}",
        published_at: devlog.created_at,
        creator: project.user.name,
        description: description,
      )
    end

    render_feed RssFeed.new(
      title: "#{AppSettings::SITE_NAME} — дневник «#{project.title}»",
      link: absolute_url("/p/#{project.slug}"),
      description: "Записи дневника проекта «#{project.title}»",
      self_url: self_url,
      items: items,
    )
  end
end
