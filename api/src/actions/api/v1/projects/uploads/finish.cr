require "uuid"

# Turns a fully received upload into a Build.
#
# Downloadable builds are moved into Latch storage. Browser builds are checked
# (quota, archive shape, index.html) and unpacked into public/media/web; the
# zip itself is not kept.
class Api::V1::Projects::Uploads::Finish < ApiAction
  include Api::V1::Projects::RequireOwner

  class Failure < Exception
    getter status : Int32
    getter code : String
    getter details : Hash(String, Array(String))?

    def initialize(
      @status : Int32,
      @code : String,
      message : String,
      @details : Hash(String, Array(String))? = nil,
    )
      super(message)
    end
  end

  post "/api/v1/projects/:slug/uploads/:token/finish" do
    session = UploadSessionQuery.new
      .token(params.get(:token))
      .user_id(current_user.id)
      .project_id(project.id)
      .first? || raise Avram::RecordNotFoundError.new(UploadSession.table_name, params.get(:token).to_s)

    UploadFiles.lock(session.token).synchronize do
      session = UploadSessionQuery.new.id(session.id).first? || raise upload_not_found

      if session.received_bytes != session.total_bytes || UploadFiles.size(session.token) != session.total_bytes
        return upload_error(422, "upload_incomplete", "The upload is not complete yet")
      end

      build = begin
        finalize_upload(session)
      rescue error : Failure
        return upload_error(error.status, error.code, error.message || "The upload failed", error.details)
      end

      DeleteUploadSession.run!(session: session)
      json BuildSerializer.new(build, project, with_usage: true), status: 201
    end
  end

  private def finalize_upload(session : UploadSession) : Build
    fields = build_fields

    case session.kind
    when "file"
      finalize_file(session, fields)
    when "web"
      finalize_web(session, fields)
    else
      raise Failure.new(422, "invalid_upload", "Unknown upload kind")
    end
  end

  private def finalize_file(session : UploadSession, fields) : Build
    public_id = UUID.random.to_s
    stored = BuildStorage.store_file(UploadFiles.part_path(session.token), session.filename, public_id)

    begin
      SaveBuild.create!(
        label: fields[:label],
        platform: fields[:platform],
        version: fields[:version],
        project_id: project.id,
        public_id: public_id,
        kind: "file",
        size_bytes: session.total_bytes,
        stored_file: stored,
      )
    rescue error
      stored.delete
      raise error
    end
  end

  private def finalize_web(session : UploadSession, fields) : Build
    part_path = UploadFiles.part_path(session.token)

    info = begin
      WebBuildArchive.inspect(part_path, fields[:entry])
    rescue error : WebBuildArchive::Error
      raise Failure.new(422, error.code, error.message || "Invalid archive")
    end

    check_web_quota!(session, info.uncompressed_bytes)

    public_id = UUID.random.to_s
    destination = BuildStorage.web_dir(public_id)
    Dir.mkdir_p(destination)

    begin
      WebBuildArchive.extract(part_path, destination, info.uncompressed_bytes)
    rescue error : WebBuildArchive::Error
      BuildStorage.remove_web_dir(public_id)
      raise Failure.new(422, error.code, error.message || "Invalid archive")
    rescue error
      BuildStorage.remove_web_dir(public_id)
      raise error
    end

    begin
      SaveBuild.create!(
        label: fields[:label],
        platform: fields[:platform],
        version: fields[:version],
        project_id: project.id,
        public_id: public_id,
        kind: "web",
        entry_path: info.entry,
        size_bytes: info.uncompressed_bytes,
      )
    rescue error
      BuildStorage.remove_web_dir(public_id)
      raise error
    end
  end

  # The reserved size is the zip; the quota has to hold the unpacked files.
  private def check_web_quota!(session : UploadSession, unpacked : Int64) : Nil
    delta = unpacked - session.total_bytes

    if StorageUsage.for_project(project.id).total + delta > AppSettings.project_storage_limit
      raise Failure.new(422, "project_storage_quota_exceeded",
        "The unpacked build does not fit in the project limit")
    end

    if StorageUsage.for_user(current_user.id).total + delta > AppSettings.account_storage_limit
      raise Failure.new(422, "storage_quota_exceeded",
        "The unpacked build does not fit in the account limit")
    end

    if StorageUsage.server_total + delta > AppSettings.server_storage_limit
      raise Failure.new(503, "storage_full", "The server has no room for this build")
    end

    if free = DiskSpace.available_bytes
      if free - AppSettings.storage_reserve < unpacked
        raise Failure.new(503, "storage_full", "The server has no room for this build")
      end
    end
  end

  private def build_fields
    values = params.nested?("build")
    label = values["label"]?.to_s.strip
    label = "Скачать" if label.empty?

    details = {} of String => Array(String)
    details["label"] = ["is too long"] if label.size > 80

    platform = values["platform"]?.to_s.strip.presence
    version = values["version"]?.to_s.strip.presence
    details["platform"] = ["is too long"] if (platform.try(&.size) || 0) > 40
    details["version"] = ["is too long"] if (version.try(&.size) || 0) > 40

    unless details.empty?
      raise Failure.new(422, "validation_failed", "Validation failed", details)
    end

    {
      label:    label,
      platform: platform,
      version:  version,
      entry:    values["entry"]?.to_s.strip.presence,
    }
  end

  private def upload_not_found : Avram::RecordNotFoundError
    Avram::RecordNotFoundError.new(UploadSession.table_name, params.get(:token).to_s)
  end

  private def upload_error(
    status : Int32,
    code : String,
    message : String,
    details : Hash(String, Array(String))? = nil,
  )
    json ErrorSerializer.new(code: code, message: message, details: details), status: status
  end
end
