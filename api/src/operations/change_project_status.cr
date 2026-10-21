class ChangeProjectStatus < Avram::Operation
  needs project : Project
  needs publish : Bool

  def run
    if publish
      Project::SaveOperation.update!(
        project,
        status: "published",
        published_at: project.published_at || Time.utc,
      )
    else
      Project::SaveOperation.update!(project, status: "draft", published_at: nil)
    end
  end
end
