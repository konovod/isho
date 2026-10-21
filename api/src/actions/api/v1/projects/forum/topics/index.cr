class Api::V1::Projects::Forum::Topics::Index < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Projects::ProjectParams
  include Api::V1::Forum::Params

  get "/api/v1/projects/:slug/forum/topics" do
    unless project_visible?
      raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
    end

    page = current_page
    per_page = page_size(AppSettings::FORUM_TOPICS_PER_PAGE, 50)

    query = ForumTopicQuery.new
      .for_project(project.id)
      .newest_activity
      .preload_user
      .preload_section
      .preload_project

    total = query.clone.select_count
    topics = query
      .limit(per_page)
      .offset((page - 1) * per_page)
      .results

    json({
      items: topics.map { |topic| ForumTopicSerializer.new(topic) },
      meta:  pagination_meta(page, per_page, total),
    })
  end
end
