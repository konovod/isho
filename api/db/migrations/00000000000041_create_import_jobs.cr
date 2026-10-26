# One attempt to build a project draft from a page the author owns. The row
# advances step by step in the import worker, and the draft project appears only
# after the page was read and the model answered, so a failed fetch leaves no
# empty project behind.
class CreateImportJobs::V00000000000041 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(ImportJob) do
      primary_key id : Int64
      add_timestamps
      add_belongs_to user : User, on_delete: :cascade
      # Null until the draft exists; deleting the project keeps the job history.
      add_belongs_to project : Project?, on_delete: :nullify
      add source_url : String
      # queued | running | done | failed | skipped | cancelled
      add status : String
      # fetch | extract | ai | screenshots | done
      add step : String
      # JSON snapshot of the page and of the model's answer: enough to explain
      # an odd draft later without calling the provider again.
      add result : String?
      add error : String?
      add attempts : Int32, default: 0
      add run_after : Time
      add started_at : Time?
      add finished_at : Time?
      add prompt_tokens : Int32, default: 0
      add completion_tokens : Int32, default: 0
    end

    # One active import per account is enough; the index also serves the
    # "is anything running for this user" check.
    create_index table_for(ImportJob), [:user_id, :status]
  end

  def rollback
    drop table_for(ImportJob)
  end
end
