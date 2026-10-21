# Removes a user with everything they own. Forum content has to go through
# DeleteUserContent first: database cascades would leave reply counters on other
# users' topics stale.
class DeleteUserAccount < Avram::Operation
  needs user : User

  def run
    delete_screenshot_files
    DeleteUserContent.run!(user: user)

    AppDatabase.transaction do
      User::DeleteOperation.delete!(user)
      purge_orphan_tags
    end
  end

  private def delete_screenshot_files
    ProjectQuery.new.for_user(user.id).preload_screenshots.results.each do |project|
      project.screenshots.each do |screenshot|
        screenshot.image.try(&.delete)
      end
    end
  end

  # Tags are shared between authors, so only tags that no project uses anymore
  # can be removed together with the account.
  private def purge_orphan_tags
    TagQuery.new.results.each do |tag|
      next if ProjectTagQuery.new.tag_id(tag.id).first?

      Tag::DeleteOperation.delete!(tag)
    end
  end
end
