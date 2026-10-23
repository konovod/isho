class MarkdownImageQuery < MarkdownImage::BaseQuery
  def older_than(time : Time)
    created_at.lt(time)
  end
end
