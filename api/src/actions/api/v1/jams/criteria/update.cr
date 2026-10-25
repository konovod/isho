class Api::V1::Jams::Criteria::Update < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  patch "/api/v1/jams/:slug/criteria/:id" do
    if JamScoring.locked?(jam)
      return json ErrorSerializer.new(
        code: "criteria_locked",
        message: "Критерии нельзя менять после начала оценивания",
      ), status: 422
    end

    criterion = find_criterion!
    updated = SaveJamCriterion.update!(criterion, params)

    json JamCriterionSerializer.new(updated)
  end

  private def find_criterion! : JamCriterion
    JamCriterionQuery.new
      .for_jam(jam.id)
      .id(params.get(:id))
      .first? || raise Avram::RecordNotFoundError.new(JamCriterion.table_name, params.get(:id).to_s)
  end
end
