class TagQuery < Tag::BaseQuery
  def search(term : String)
    name.ilike("%#{term}%").or(&.slug.ilike("%#{term}%"))
  end
end
