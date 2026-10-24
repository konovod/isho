class Api::V1::Jams::Update < ApiAction
  include Api::V1::Jams::RequireOwner
  include Api::Auth::RequireConfirmedEmail

  patch "/api/v1/jams/:slug" do
    updated = SaveJam.update!(jam, params)

    json JamSerializer.new(reload_jam(updated), current_user?, detailed: true)
  end
end
