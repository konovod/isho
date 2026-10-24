# Where hosted browser builds live.
#
# `MEDIA_ORIGIN` is the base origin (`https://isho-games.duckdns.org`). Every
# project gets its own host under it, so one game cannot read another game's
# saves, Cache Storage or IndexedDB: browser storage is per origin, and games
# share nothing. All builds of one project share their host, so an updated
# build keeps the player's progress.
module MediaOrigin
  # A DNS label is at most 63 characters while slugs may be longer; a name that
  # does not fit falls back to the project id instead of a truncated slug that
  # another project could share.
  MAX_LABEL = 63

  def self.base : String?
    AppSettings.media_origin
  end

  def self.host : String?
    AppSettings.media_host
  end

  # The base host and every per-project host under it.
  def self.host?(hostname : String) : Bool
    base = host
    !base.nil? && (hostname == base || hostname.ends_with?(".#{base}"))
  end

  def self.subdomain(project : Project) : String
    project.slug.size <= MAX_LABEL ? project.slug : "p#{project.id}"
  end

  # An absolute URL when a media origin is configured, the plain path otherwise
  # (development and tests keep working without one).
  def self.url(project : Project, path : String) : String
    origin = base
    return path unless origin

    uri = URI.parse(origin)
    host = "#{subdomain(project)}.#{uri.host}"
    host = "#{host}:#{uri.port}" if uri.port
    "#{uri.scheme}://#{host}#{path}"
  end
end
