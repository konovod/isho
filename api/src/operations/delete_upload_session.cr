# Cancels an unfinished upload and frees the bytes it reserved.
class DeleteUploadSession < Avram::Operation
  needs session : UploadSession

  def run
    UploadFiles.delete(session.token)
    UploadSession::DeleteOperation.delete!(session)
  end
end
