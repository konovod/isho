class Api::V1::Projects::Uploads::Delete < ApiAction
  include Api::V1::Projects::ProjectParams

  delete "/api/v1/projects/:slug/uploads/:token" do
    session = UploadSessionQuery.new
      .token(params.get(:token))
      .user_id(current_user.id)
      .project_id(project.id)
      .first? || raise Avram::RecordNotFoundError.new(UploadSession.table_name, params.get(:token).to_s)

    DeleteUploadSession.run!(session: session)
    head 204
  end
end
