class JamQuery < Jam::BaseQuery
  def published
    status("published")
  end

  def for_user(owner_id : Int64)
    user_id(owner_id)
  end

  def search(term : String)
    title.ilike("%#{term}%")
  end

  # The page needs the organizer and the linked forum category; criteria are
  # loaded only for the detail page.
  def preload_card
    preload_user
  end

  def preload_detail
    preload_user
      .preload_forum_section
      .preload_criteria
  end
end
