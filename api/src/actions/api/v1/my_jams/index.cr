class Api::V1::MyJams::Index < ApiAction
  get "/api/v1/my_jams" do
    jams = JamQuery.new
      .for_user(current_user.id)
      .preload_card
      .created_at.desc_order
      .results

    json({items: jams.map { |jam| JamSerializer.new(jam, current_user?) }})
  end
end
