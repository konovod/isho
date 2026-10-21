class Api::V1::Projects::Screenshots::Update < ApiAction
  include Api::V1::Projects::RequireOwner
  include Api::V1::Projects::Screenshots::Params

  patch "/api/v1/projects/:slug/screenshots/:id" do
    updated = SaveScreenshot.update!(screenshot, params)

    if updated.is_cover
      project.screenshots.each do |other|
        next if other.id == updated.id || !other.is_cover
        Screenshot::SaveOperation.update!(other, is_cover: false)
      end
    end

    json ScreenshotSerializer.new(updated)
  end
end
