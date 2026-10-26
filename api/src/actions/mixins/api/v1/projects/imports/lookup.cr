# Finds an import job of the current account. Somebody else's job is a 404, the
# same way a stranger's draft is: the address must not confirm it exists.
module Api::V1::Projects::Imports::Lookup
  private def import_job : ImportJob
    raw = params.get(:id)
    id = raw.to_i64? || raise Avram::RecordNotFoundError.new(ImportJob.table_name, raw.to_s)

    ImportJobQuery.new.id(id).for_user(current_user.id).first? ||
      raise Avram::RecordNotFoundError.new(ImportJob.table_name, id.to_s)
  end
end
