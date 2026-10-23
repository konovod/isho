class Api::V1::Projects::Uploads::Show < ApiAction
  include Api::V1::Projects::ProjectParams

  get "/api/v1/projects/:slug/uploads/:token" do
    session = UploadSessionQuery.new
      .token(params.get(:token))
      .user_id(current_user.id)
      .project_id(project.id)
      .first? || raise Avram::RecordNotFoundError.new(UploadSession.table_name, params.get(:token).to_s)

    json({
      token:          session.token,
      chunk_size:     AppSettings::UPLOAD_CHUNK_BYTES,
      total_bytes:    session.total_bytes,
      received_bytes: session.received_bytes,
      kind:           session.kind,
      filename:       session.filename,
    })
  end
end
