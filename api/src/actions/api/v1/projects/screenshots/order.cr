class Api::V1::Projects::Screenshots::Order < ApiAction
  include Api::V1::Projects::RequireOwner

  put "/api/v1/projects/:slug/screenshots/order" do
    ids = params.get_all?(:ids)

    unless ids
      return json(ErrorSerializer.new(
        code: "validation_failed",
        message: "ids is required",
        details: {"ids" => ["is required"]},
      ), status: 422)
    end

    screenshots = ScreenshotQuery.new.project_id(project.id).results
    by_id = screenshots.index_by(&.id)

    ids.each_with_index do |id, index|
      if screenshot = by_id[id.to_i64]?
        Screenshot::SaveOperation.update!(screenshot, position: index)
      end
    end

    ordered = ScreenshotQuery.new.project_id(project.id).ordered.results
    json({items: ordered.map { |screenshot| ScreenshotSerializer.new(screenshot) }})
  end
end
