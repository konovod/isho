class DownloadQuery < Download::BaseQuery
  def ordered
    created_at.asc_order
  end
end
