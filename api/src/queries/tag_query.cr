class TagQuery < Tag::BaseQuery
  def alphabetical
    name.asc_order
  end
end
