class Api::V1::Projects::Imports::Show < ApiAction
  include Api::V1::Projects::Imports::Lookup

  get "/api/v1/projects/imports/:id" do
    job = import_job
    project = job.project_id.try { |id| ProjectQuery.new.id(id).first? }

    json({import: ImportJobSerializer.new(job, project)})
  end
end
