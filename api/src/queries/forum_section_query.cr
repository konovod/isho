class ForumSectionQuery < ForumSection::BaseQuery
  def ordered
    position.asc_order
  end

  def by_slug(slug : String)
    slug(slug)
  end
end
