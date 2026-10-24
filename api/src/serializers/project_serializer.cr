class ProjectSerializer < BaseSerializer
  def initialize(
    @project : Project,
    @detailed : Bool = false,
    @moderation : Bool = false,
    @with_usage : Bool = false,
  )
  end

  def render
    base = {
      id:           @project.id,
      slug:         @project.slug,
      title:        @project.title,
      tagline:      @project.tagline,
      kind:         @project.kind,
      status:       @project.status,
      nsfw:         @project.nsfw,
      ai_usage:     @project.ai_usage,
      published_at: @project.published_at,
      cover_url:    cover_url,
      author:       UserSerializer.new(@project.user),
      tags:         tags,
    }

    if @detailed
      detailed = base.merge({
        description: @project.description,
        screenshots: screenshots,
        downloads:   downloads,
        builds:      builds,
      })

      @moderation ? detailed.merge(moderation) : detailed
    else
      base
    end
  end

  # Only the author and moderators may see why a project was unpublished.
  private def moderation
    {
      moderation_note: @project.moderation_note,
      moderated_at:    @project.moderated_at,
    }
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

  private def builds : Array(BuildSerializer)
    return [] of BuildSerializer unless @project.builds_preloaded?

    @project.builds.sort_by(&.id).map { |build| BuildSerializer.new(build, @project, with_usage: @with_usage) }
  end

  private def cover_url : String?
    return nil unless @project.screenshots_preloaded?

    screenshot = @project.cover
    file = screenshot.try(&.image)
    return nil unless file

    (file.versions_card? || file).url.gsub('\\', '/')
  end
end
