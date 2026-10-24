class Api::V1::MyProjects::Index < ApiAction
  get "/api/v1/me/projects" do
    projects = ProjectQuery.new
      .for_user(current_user.id)
      .created_at.desc_order
      .preload_user
      .preload_screenshots
      .preload_downloads
      .preload_builds
      .preload_tags
      .results

    json({items: projects.map { |project| ProjectSerializer.new(project, detailed: true, moderation: true, with_usage: true) }})
  end
end
