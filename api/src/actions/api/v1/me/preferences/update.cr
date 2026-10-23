class Api::V1::Me::Preferences::Update < ApiAction
  # Content preferences are separate from the profile: SaveProfile expects the
  # whole profile payload, while this route only touches the viewer settings.
  patch "/api/v1/me/preferences" do
    user = SavePreferences.update!(current_user, params)
    json MeSerializer.new(user)
  end
end
