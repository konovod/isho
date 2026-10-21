class DevlogQuery < Devlog::BaseQuery
  def newest
    created_at.desc_order
  end
end
