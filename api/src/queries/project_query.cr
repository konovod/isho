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
end
