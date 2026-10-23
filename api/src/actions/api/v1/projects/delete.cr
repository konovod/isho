class Api::V1::Projects::Delete < ApiAction
  include Api::V1::Projects::RequireOwner

  delete "/api/v1/projects/:slug" do
    project.screenshots.each do |screenshot|
      screenshot.image.try(&.delete)
    end

    project.builds.each do |build|
      BuildStorage.delete_files(build)
    end

    Project::DeleteOperation.delete!(project)
    head 204
  end
end
