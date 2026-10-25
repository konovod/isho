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

  # A catalogue filter needs a project to carry every selected tag, so the
  # subquery groups by project and keeps only full matches. The same condition
  # also narrows tag counts, which is what makes the next tag "compatible".
  def with_all_tags(tag_ids : Array(Int64)) : self
    return self if tag_ids.empty?

    where(<<-SQL, tag_ids, tag_ids.size)
      projects.id IN (
        SELECT project_tags.project_id
        FROM project_tags
        WHERE project_tags.tag_id = ANY(?::bigint[])
        GROUP BY project_tags.project_id
        HAVING COUNT(DISTINCT project_tags.tag_id) = ?
      )
    SQL
  end

  # Matches the card's «Играть»: a browser build with an entry point.
  def with_web_build : self
    where(<<-SQL)
      EXISTS (
        SELECT 1 FROM builds
        WHERE builds.project_id = projects.id
          AND builds.kind = 'web'
          AND builds.entry_path IS NOT NULL
          AND builds.entry_path <> ''
      )
    SQL
  end
end
