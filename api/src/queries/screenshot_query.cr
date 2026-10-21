class ScreenshotQuery < Screenshot::BaseQuery
  def ordered
    position.asc_order
  end
end
