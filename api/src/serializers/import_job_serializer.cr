class ImportJobSerializer < BaseSerializer
  def initialize(@job : ImportJob, @project : Project? = nil)
  end

  def render
    {
      id:         @job.id,
      status:     @job.status,
      step:       @job.step,
      source_url: @job.source_url,
      error:      @job.error,
      # The page navigates to the draft as soon as it exists.
      project_slug: @project.try(&.slug),
      created_at:   @job.created_at,
      finished_at:  @job.finished_at,
    }
  end
end
