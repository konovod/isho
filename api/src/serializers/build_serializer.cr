class BuildSerializer < BaseSerializer
  # The project is passed in: play URLs are per project, and every caller
  # already has it loaded.
  def initialize(@build : Build, @project : Project, @with_usage : Bool = false)
  end

  def render
    base = {
      id:         @build.id,
      kind:       @build.kind,
      label:      @build.label,
      platform:   @build.platform,
      version:    @build.version,
      size_bytes: @build.size_bytes,
      url:        file_url,
      play_url:   play_url,
      entry_path: @build.entry_path,
      created_at: @build.created_at,
    }

    @with_usage ? base.merge(usage) : base
  end

  # Counters are for the author only, so they are absent from every response
  # that is not built for the owner.
  private def usage
    {
      downloads_count: @build.downloads_count,
      launches_count:  @build.launches_count,
    }
  end

  private def file_url : String?
    @build.stored_file.try { |file| URI.encode_path(file.url.gsub('\\', '/')) }
  end

  private def play_url : String?
    return nil unless @build.web?

    entry = @build.entry_path
    return nil if entry.nil? || entry.empty?

    path = "/media/web/#{BuildStorage.safe_public_id(@build.public_id)}/#{URI.encode_path(entry)}"
    MediaOrigin.url(@project, path)
  end
end
