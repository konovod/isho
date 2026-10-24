class Api::V1::Jams::Criteria::Delete < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  delete "/api/v1/jams/:slug/criteria/:id" do
    criterion = find_criterion!
    JamCriterion::DeleteOperation.delete!(criterion)
    head 204
  end

  private def find_criterion! : JamCriterion
    JamCriterionQuery.new
      .for_jam(jam.id)
      .id(params.get(:id))
      .first? || raise Avram::RecordNotFoundError.new(JamCriterion.table_name, params.get(:id).to_s)
  end
end
