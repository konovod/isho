class Api::V1::Jams::EligibleProjects < ApiAction
  include Api::V1::Jams::JamParams

  get "/api/v1/jams/:slug/eligible_projects" do
    unless JamPhase.accepts_entries?(jam)
      return json ErrorSerializer.new(
        code: "jam_not_open",
        message: "Приём заявок закрыт",
      ), status: 422
    end

    entered_ids = JamEntryQuery.new
      .for_jam(jam.id)
      .results
      .map(&.project_id)

    projects = ProjectQuery.new
      .for_user(current_user.id)
      .published
      .preload_user
      .preload_screenshots
      .preload_tags
      .preload_builds
      .published_at.desc_order
      .results
      .reject { |project| entered_ids.includes?(project.id) }

    json({items: projects.map { |project| ProjectSerializer.new(project) }})
  end
end
