# Cancelling only stops a job that has not started: a running import finishes
# its step and then checks for the cancellation before creating the draft.
class Api::V1::Projects::Imports::Delete < ApiAction
  include Api::V1::Projects::Imports::Lookup

  delete "/api/v1/projects/imports/:id" do
    job = import_job

    unless job.finished?
      job = SaveImportJob.update!(
        job,
        status: "cancelled",
        finished_at: Time.utc,
        error: "импорт отменён",
      )
    end

    json({import: ImportJobSerializer.new(job)})
  end
end
