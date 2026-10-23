class MarkdownImageSerializer < BaseSerializer
  def initialize(@image : MarkdownImage)
  end

  def render
    {
      id:  @image.id,
      url: public_url(@image.image.try(&.url)),
    }
  end

  private def public_url(url : String?) : String?
    url.try(&.gsub('\\', '/'))
  end
end
