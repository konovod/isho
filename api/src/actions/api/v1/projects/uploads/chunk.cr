# Accepts one 8 MB slice of an upload as a raw request body.
#
# The body is streamed straight to the scratch file; nothing keeps the chunk
# in memory, which is what makes a 300 MB build possible on a small server.
class Api::V1::Projects::Uploads::Chunk < ApiAction
  include Api::V1::Projects::ProjectParams
  include Api::Auth::RequireNotBanned

  put "/api/v1/projects/:slug/uploads/:token/chunks/:index" do
    session = find_session
    index = params.get(:index).to_i64?

    unless index && index >= 0
      return chunk_error(422, "invalid_chunk", "The chunk index is invalid")
    end

    UploadFiles.lock(session.token).synchronize do
      # A retry may arrive after the first attempt was already stored.
      session = UploadSessionQuery.new.id(session.id).first? || raise upload_not_found

      offset = session.received_bytes
      current_index = offset // AppSettings::UPLOAD_CHUNK_BYTES

      if offset >= session.total_bytes
        return json chunk_json(session, offset)
      end

      if index < current_index
        return json chunk_json(session, offset)
      end

      if index > current_index
        return chunk_error(422, "invalid_chunk", "Expected chunk #{current_index}")
      end

      expected = Math.min(AppSettings::UPLOAD_CHUNK_BYTES, session.total_bytes - offset)
      if expected <= 0
        return chunk_error(422, "upload_complete", "The upload is already complete")
      end

      length = context.request.headers["Content-Length"]?.try(&.to_i64?)
      if length && length != expected
        return chunk_error(422, "invalid_chunk", "A chunk must be #{expected} bytes")
      end

      written = write_chunk(session, offset, expected)
      unless written == expected
        return chunk_error(422, "upload_interrupted", "The chunk was not fully received")
      end

      new_offset = offset + written
      UploadSession::SaveOperation.update!(session, received_bytes: new_offset)
      json chunk_json(session, new_offset)
    end
  end

  private def find_session : UploadSession
    UploadSessionQuery.new
      .token(params.get(:token))
      .user_id(current_user.id)
      .project_id(project.id)
      .first? || raise upload_not_found
  end

  private def upload_not_found : Avram::RecordNotFoundError
    Avram::RecordNotFoundError.new(UploadSession.table_name, params.get(:token).to_s)
  end

  # Writes exactly `expected` bytes at `offset`, truncating anything a previous
  # failed attempt may have left behind.
  private def write_chunk(session : UploadSession, offset : Int64, expected : Int64) : Int64
    path = UploadFiles.part_path(session.token)
    raise upload_not_found unless File.exists?(path)

    body = context.request.body
    return 0_i64 unless body

    written = 0_i64

    begin
      File.open(path, "r+") do |file|
        file.truncate(offset) if file.size > offset
        file.seek(offset)

        buffer = Bytes.new(64 * 1024)
        while written < expected
          want = Math.min(buffer.size.to_i64, expected - written).to_i
          read = body.read(buffer[0, want])
          break if read == 0

          file.write(buffer[0, read])
          written += read
        end

        file.flush
      end
    rescue error : IO::Error
      UploadFiles.truncate(session.token, offset)
      return 0_i64
    end

    UploadFiles.truncate(session.token, offset) if written != expected
    written
  end

  private def chunk_json(session : UploadSession, received : Int64)
    {
      token:          session.token,
      received_bytes: received,
      total_bytes:    session.total_bytes,
      next_index:     received // AppSettings::UPLOAD_CHUNK_BYTES,
    }
  end

  private def chunk_error(status : Int32, code : String, message : String)
    json ErrorSerializer.new(code: code, message: message), status: status
  end
end
