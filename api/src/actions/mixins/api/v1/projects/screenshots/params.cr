module Api::V1::Projects::Screenshots::Params
  memoize def screenshot : Screenshot
    ScreenshotQuery.new
      .id(params.get(:id))
      .project_id(project.id)
      .first? || raise Avram::RecordNotFoundError.new(Screenshot.table_name, params.get(:id).to_s)
  end
end
