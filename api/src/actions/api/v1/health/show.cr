class Api::V1::Health::Show < ApiAction
  include Api::Auth::SkipRequireSession

  get "/api/v1/health" do
    json({status: "ok", time: Time.utc})
  end
end
