class ForumSectionQuery < ForumSection::BaseQuery
  def ordered
    position.asc_order.id.asc_order
  end

  def roots
    parent_id.is_nil
  end

  def children_of(parent : Int64)
    parent_id(parent)
  end

  def by_slug(slug : String)
    slug(slug)
  end
end
