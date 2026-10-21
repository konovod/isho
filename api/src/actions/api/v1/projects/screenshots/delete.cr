class Api::V1::Projects::Screenshots::Delete < ApiAction
  include Api::V1::Projects::RequireOwner
  include Api::V1::Projects::Screenshots::Params

  delete "/api/v1/projects/:slug/screenshots/:id" do
    was_cover = screenshot.is_cover
    Screenshot::DeleteOperation.delete!(screenshot)

    if was_cover
      if next_screenshot = ScreenshotQuery.new.project_id(project.id).ordered.first?
        Screenshot::SaveOperation.update!(next_screenshot, is_cover: true)
      end
    end

    head 204
  end
end
