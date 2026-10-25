# Entries follow their project's visibility. The author and the jam organizer
# still see an entry whose project was unpublished or hidden by content
# preferences; everybody else does not.
module JamEntryVisibility
  def self.visible?(entry : JamEntry, viewer : User?) : Bool
    project = entry.project

    if viewer && (viewer.id == entry.user_id || viewer.id == project.user_id || viewer.moderator?)
      return true
    end

    project.published? && project.content_visible_to?(viewer)
  end

  def self.visible(entries : Array(JamEntry), viewer : User?) : Array(JamEntry)
    entries.select { |entry| visible?(entry, viewer) }
  end

  # A count for list cards. Entries must have their project preloaded.
  def self.count(entries : Array(JamEntry), viewer : User?) : Int64
    visible(entries, viewer).size.to_i64
  end
end
