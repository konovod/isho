class DownloadSerializer < BaseSerializer
  def initialize(@download : Download)
  end

  def render
    {
      id:       @download.id,
      label:    @download.label,
      url:      @download.url,
      platform: @download.platform,
      version:  @download.version,
    }
  end
end
