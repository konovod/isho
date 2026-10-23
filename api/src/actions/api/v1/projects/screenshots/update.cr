class Api::V1::Projects::Screenshots::Update < ApiAction
  include Api::V1::Projects::RequireOwner
  include Api::V1::Projects::Screenshots::Params

  patch "/api/v1/projects/:slug/screenshots/:id" do
    json ScreenshotSerializer.new(UpdateScreenshot.update!(screenshot, params))
  end
end
