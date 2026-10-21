class Api::V1::Projects::Downloads::Delete < ApiAction
  include Api::V1::Projects::RequireOwner

  delete "/api/v1/projects/:slug/downloads/:id" do
    download = DownloadQuery.new
      .id(params.get(:id))
      .project_id(project.id)
      .first? || raise Avram::RecordNotFoundError.new(Download.table_name, params.get(:id).to_s)

    Download::DeleteOperation.delete!(download)
    head 204
  end
end
