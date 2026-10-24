class Api::V1::Me::Show < ApiAction
  get "/api/v1/me" do
    json MeSerializer.new(current_user, impersonation)
  end
end
