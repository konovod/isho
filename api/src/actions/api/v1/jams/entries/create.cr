class Api::V1::Jams::Entries::Create < ApiAction
  include Api::V1::Jams::JamParams
  include Api::Auth::RequireConfirmedEmail
  include Api::Auth::RequireNotBanned

  post "/api/v1/jams/:slug/entries" do
    unless JamPhase.accepts_entries?(jam)
      return json ErrorSerializer.new(
        code: "jam_not_open",
        message: "Приём заявок закрыт",
      ), status: 422
    end

    fields = params.nested?("jam_entry")
    project_slug = fields["project_slug"]?.to_s.strip

    if project_slug.empty?
      return json ErrorSerializer.new(
        code: "validation_failed",
        message: "Выберите проект",
        details: {"project_slug" => ["is required"]},
      ), status: 422
    end

    project = ProjectQuery.new
      .slug(project_slug)
      .for_user(current_user.id)
      .preload_user
      .preload_screenshots
      .preload_tags
      .preload_builds
      .first?

    unless project
      return json ErrorSerializer.new(
        code: "project_not_found",
        message: "Проект не найден среди ваших проектов",
      ), status: 422
    end

    unless project.published?
      return json ErrorSerializer.new(
        code: "project_not_published",
        message: "Сначала опубликуйте проект",
      ), status: 422
    end

    if JamEntryQuery.new.for_jam(jam.id).project_id(project.id).first?
      return json ErrorSerializer.new(
        code: "already_submitted",
        message: "Этот проект уже подан в этот джем",
      ), status: 422
    end

    entry = CreateJamEntry.run!(jam: jam, user: current_user, project: project)

    json JamEntrySerializer.new(reload_entry(entry)), status: 201
  end

  private def reload_entry(entry : JamEntry) : JamEntry
    JamEntryQuery.new.id(entry.id).preload_card.first? ||
      raise Avram::RecordNotFoundError.new(JamEntry.table_name, entry.id.to_s)
  end
end
