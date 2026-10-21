class ProjectSerializer < BaseSerializer
  def initialize(@project : Project, @detailed : Bool = false)
  end

  def render
    base = {
      id:           @project.id,
      slug:         @project.slug,
      title:        @project.title,
      tagline:      @project.tagline,
      kind:         @project.kind,
      status:       @project.status,
      published_at: @project.published_at,
      cover_url:    cover_url,
      author:       UserSerializer.new(@project.user),
      tags:         tags,
    }

    if @detailed
      base.merge({
        description: @project.description,
        screenshots: screenshots,
        downloads:   downloads,
      })
    else
      base
    end
  end

  private def tags : Array(TagSerializer)
    return [] of TagSerializer unless @project.tags_preloaded?

    @project.tags.map { |tag| TagSerializer.new(tag) }
  end

  private def screenshots : Array(ScreenshotSerializer)
    return [] of ScreenshotSerializer unless @project.screenshots_preloaded?

    @project.screenshots.sort_by(&.position).map { |screenshot| ScreenshotSerializer.new(screenshot) }
  end

  private def downloads : Array(DownloadSerializer)
    return [] of DownloadSerializer unless @project.downloads_preloaded?

    @project.downloads.map { |download| DownloadSerializer.new(download) }
  end

  private def cover_url : String?
    return nil unless @project.screenshots_preloaded?

    screenshot = @project.cover
    file = screenshot.try(&.image)
    return nil unless file

    (file.versions_card? || file).url.gsub('\\', '/')
  end
end
