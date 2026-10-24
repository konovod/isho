# Publishing is also where the forum category appears. The section and the
# status change share a transaction: a half-published jam would show a forum
# link that does not exist, or leave an orphan section behind.
class PublishJam < Avram::Operation
  needs jam : Jam

  def run
    AppDatabase.transaction do
      section = JamForumSection.create_for(jam)

      Jam::SaveOperation.update!(
        jam,
        status: "published",
        published_at: jam.published_at || Time.utc,
        forum_section_id: section.id,
      )
    end
  end
end
