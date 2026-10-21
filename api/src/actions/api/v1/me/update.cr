class Api::V1::Me::Update < ApiAction
  patch "/api/v1/me" do
    user = SaveProfile.update!(current_user, params)
    json MeSerializer.new(user)
  end
end
