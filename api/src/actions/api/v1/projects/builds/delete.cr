class Api::V1::Projects::Builds::Delete < ApiAction
  include Api::V1::Projects::RequireOwner

  delete "/api/v1/projects/:slug/builds/:id" do
    build = BuildQuery.new
      .id(params.get(:id))
      .project_id(project.id)
      .first? || raise Avram::RecordNotFoundError.new(Build.table_name, params.get(:id).to_s)

    DeleteBuild.run!(build: build)
    head 204
  end
end
