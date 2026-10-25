class Api::V1::Projects::Jams::Index < ApiAction
  include Api::Auth::SkipRequireSession
  include Api::V1::Projects::ProjectParams

  get "/api/v1/projects/:slug/jams" do
    unless project_visible?
      raise Avram::RecordNotFoundError.new(Project.table_name, params.get(:slug).to_s)
    end

    entries = JamEntryQuery.new
      .for_project(project.id)
      .preload_jam
      .newest
      .results

    viewer = current_user?
    owner = !!viewer && (viewer.id == project.user_id || viewer.moderator?)
    entries = entries.select(&.submitted?) unless owner

    json({items: entries.map { |entry| ProjectJamEntrySerializer.new(entry) }})
  end
end
