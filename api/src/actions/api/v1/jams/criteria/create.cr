class Api::V1::Jams::Criteria::Create < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  post "/api/v1/jams/:slug/criteria" do
    if JamScoring.locked?(jam)
      return json ErrorSerializer.new(
        code: "criteria_locked",
        message: "Критерии нельзя менять после начала оценивания",
      ), status: 422
    end

    criterion = SaveJamCriterion.create!(params, jam_id: jam.id)

    json JamCriterionSerializer.new(criterion), status: 201
  end
end
