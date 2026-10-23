# Starts a chunked upload and reserves its bytes against both quotas.
#
# One unfinished upload per account is enough: a second start either resumes
# the matching session (same project, kind, name and size) or replaces it, so
# an abandoned tab cannot block a new attempt forever.
class Api::V1::Projects::Uploads::Create < ApiAction
  include Api::V1::Projects::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/projects/:slug/uploads" do
    if BuildQuery.new.project_id(project.id).select_count >= AppSettings::MAX_BUILDS
      return upload_error(422, "build_limit_reached",
        "A project can have at most #{AppSettings::MAX_BUILDS} builds")
    end

    upload = params.nested?("upload")
    kind = upload["kind"]?.to_s.strip.downcase
    total = upload["total_bytes"]?.try(&.to_i64?)
    filename = BuildStorage.safe_filename(upload["filename"]?.to_s)

    unless %w[file web].includes?(kind)
      return upload_error(422, "validation_failed", "Validation failed", {
        "kind" => ["must be file or web"],
      })
    end

    unless total && total > 0 && total <= AppSettings::BUILD_MAX_BYTES
      return upload_error(422, "validation_failed", "Validation failed", {
        "total_bytes" => ["must be between 1 and #{AppSettings::BUILD_MAX_BYTES}"],
      })
    end

    session = nil
    resumed = false
    failure = nil

    AppDatabase.transaction do
      lock_user

      existing = UploadSessionQuery.new.user_id(current_user.id).first?
      if existing
        if resumable?(existing, project.id, kind, filename, total)
          session = existing
          resumed = true
        else
          DeleteUploadSession.run!(session: existing)
        end
      end

      unless session
        failure = storage_failure(total)

        unless failure
          session = SaveUploadSession.create!(
            params,
            user_id: current_user.id,
            project_id: project.id,
            token: Random::Secure.urlsafe_base64(24),
            received_bytes: 0_i64,
          )
        end
      end
    end

    if failure
      code, message, status = failure
      return upload_error(status, code, message)
    end

    if session.nil?
      return upload_error(422, "validation_failed", "The upload could not be started")
    end

    unless resumed
      begin
        UploadFiles.create(session.token)
      rescue error
        DeleteUploadSession.run!(session: session)
        raise error
      end
    end

    json upload_json(session), status: resumed ? 200 : 201
  end

  # Serialises starts per account so a double click cannot reserve twice.
  private def lock_user : Nil
    AppDatabase.run do |db|
      db.exec("SELECT id FROM users WHERE id = $1 FOR UPDATE", current_user.id)
    end
  end

  private def resumable?(
    session : UploadSession,
    project_id : Int64,
    kind : String,
    filename : String,
    total : Int64,
  ) : Bool
    return false if session.created_at < AppSettings::UPLOAD_SESSION_TTL.ago

    session.project_id == project_id &&
      session.kind == kind &&
      session.filename == filename &&
      session.total_bytes == total
  end

  private def storage_failure(total : Int64) : Tuple(String, String, Int32)?
    project_usage = StorageUsage.for_project(project.id)
    if project_usage.total + total > AppSettings.project_storage_limit
      return {
        "project_storage_quota_exceeded",
        "The project build limit is used up",
        422,
      }
    end

    usage = StorageUsage.for_user(current_user.id)
    if usage.total + total > AppSettings.account_storage_limit
      return {"storage_quota_exceeded", "The account storage limit is used up", 422}
    end

    if StorageUsage.server_total + total > AppSettings.server_storage_limit
      return {"storage_full", "The server has no room for new uploads", 503}
    end

    if free = DiskSpace.available_bytes
      if free - AppSettings.storage_reserve < total * 2
        return {"storage_full", "The server has no room for new uploads", 503}
      end
    end

    nil
  end

  private def upload_json(session : UploadSession)
    {
      token:          session.token,
      chunk_size:     AppSettings::UPLOAD_CHUNK_BYTES,
      total_bytes:    session.total_bytes,
      received_bytes: session.received_bytes,
      kind:           session.kind,
      filename:       session.filename,
    }
  end

  private def upload_error(
    status : Int32,
    code : String,
    message : String,
    details = nil,
  )
    json ErrorSerializer.new(code: code, message: message, details: details), status: status
  end
end
