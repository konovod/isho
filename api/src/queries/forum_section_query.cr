class ForumSectionQuery < ForumSection::BaseQuery
  def ordered
    position.asc_order.id.asc_order
  end

  def by_slug(slug : String)
    slug(slug)
  end
end
