class Api::V1::Projects::Downloads::Create < ApiAction
  include Api::V1::Projects::RequireOwner

  post "/api/v1/projects/:slug/downloads" do
    if DownloadQuery.new.project_id(project.id).select_count >= AppSettings::MAX_DOWNLOADS
      return json(ErrorSerializer.new(
        code: "download_limit_reached",
        message: "A project can have at most #{AppSettings::MAX_DOWNLOADS} downloads",
      ), status: 422)
    end

    download = CreateDownload.create!(params, project_id: project.id)
    json DownloadSerializer.new(download), status: 201
  end
end
