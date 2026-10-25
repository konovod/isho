class JamEntryQuery < JamEntry::BaseQuery
  def for_jam(jam_id : Int64)
    jam_id(jam_id)
  end

  def for_project(project_id : Int64)
    project_id(project_id)
  end

  def for_user(user_id : Int64)
    user_id(user_id)
  end

  def submitted
    status("submitted")
  end

  def disqualified
    status("disqualified")
  end

  def newest
    created_at.desc_order.id.desc_order
  end

  def oldest
    created_at.asc_order.id.asc_order
  end

  # ProjectSerializer needs the author, cover and tags to build a card.
  def preload_card
    preload_user
      .preload_project(ProjectQuery.new.preload_user.preload_screenshots.preload_tags.preload_builds)
  end
end
