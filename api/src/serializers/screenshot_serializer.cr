class ScreenshotSerializer < BaseSerializer
  def initialize(@screenshot : Screenshot)
  end

  def render
    image = @screenshot.image

    {
      id:        @screenshot.id,
      caption:   @screenshot.caption,
      position:  @screenshot.position,
      is_cover:  @screenshot.is_cover,
      url:       public_url(image.try(&.url)),
      card_url:  public_url(image.try { |file| file.versions_card?.try(&.url) }),
      thumb_url: public_url(image.try { |file| file.versions_thumb?.try(&.url) }),
    }
  end

  private def public_url(url : String?) : String?
    url.try(&.gsub('\\', '/'))
  end
end
