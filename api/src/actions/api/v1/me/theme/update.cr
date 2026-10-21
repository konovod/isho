class Api::V1::Me::Theme::Update < ApiAction
  # Separate from PATCH /api/v1/me: SaveProfile clears the fields that are
  # missing from the payload, so a theme-only request would wipe the profile.
  patch "/api/v1/me/theme" do
    user = SaveTheme.update!(current_user, params)
    json MeSerializer.new(user)
  end
end
