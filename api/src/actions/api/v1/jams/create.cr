class Api::V1::Jams::Create < ApiAction
  include Api::V1::Jams::JamParams
  include Api::Auth::RequireConfirmedEmail
  include Api::Auth::RequireNotBanned

  post "/api/v1/jams" do
    jam = SaveJam.create!(params, user_id: current_user.id)

    json JamSerializer.new(reload_jam(jam), current_user?, detailed: true), status: 201
  end
end
