class BuildQuery < Build::BaseQuery
  def web
    kind("web")
  end

  def newest
    created_at.desc_order
  end
end
