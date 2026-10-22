class Api::V1::Admin::BlockedEmails::Delete < ApiAction
  include Api::Auth::RequireAdmin

  delete "/api/v1/admin/blocked_emails/:id" do
    entry = BlockedEmailQuery.new.id(params.get(:id)).first? ||
            raise Avram::RecordNotFoundError.new(BlockedEmail.table_name, params.get(:id).to_s)

    BlockedEmail::DeleteOperation.delete!(entry)
    head 204
  end
end
