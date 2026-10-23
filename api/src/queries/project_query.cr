class ProjectQuery < Project::BaseQuery
  def published
    status("published")
  end

  def newest
    published_at.desc_order
  end

  def search(term : String)
    title.ilike("%#{term}%")
  end

  def for_user(owner_id : Int64)
    user_id(owner_id)
  end

  # Projects a viewer may see in public lists. Visitors never see adult
  # projects, accounts can hide them and limit the AI usage level. Moderators
  # see everything so the moderation page stays complete.
  def visible_to(viewer : User?) : self
    query = published
    return query if viewer.try(&.moderator?)

    if user = viewer
      query = query.nsfw(false) unless user.show_nsfw
      query = query.ai_usage_at_most(user.max_ai_usage)
    else
      query = query.nsfw(false)
    end

    query
  end

  def ai_usage_at_most(level : String) : self
    highest = AppSettings.ai_usage_rank(level)
    return self if highest >= AppSettings::AI_USAGE_LEVELS.size - 1

    ai_usage.in(AppSettings::AI_USAGE_LEVELS[0..highest])
  end
end
