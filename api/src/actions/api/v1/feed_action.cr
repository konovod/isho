require "digest/sha256"

# Feeds are public data, not pages: they ignore the session cookie on purpose.
# A reader cannot send cookies, and a shared cache must get the same document
# for everyone, so all feed queries pass `nil` as the viewer.
abstract class Api::V1::FeedAction < ApiAction
  include Api::Auth::SkipRequireSession

  accepted_formats [:rss, :xml, :html], default: :rss

  ITEMS_LIMIT   =  50
  CACHE_SECONDS = 300

  private def render_feed(feed : RssFeed) : Lucky::Response
    body = feed.to_xml
    etag = %("#{Digest::SHA256.hexdigest(body)}")

    context.response.headers["ETag"] = etag
    context.response.headers["Cache-Control"] = "public, max-age=#{CACHE_SECONDS}"

    if context.request.headers["If-None-Match"]?.try(&.includes?(etag))
      return head(304)
    end

    xml body, content_type: "application/rss+xml; charset=utf-8"
  end

  private def absolute_url(path : String) : String
    "#{AppSettings.public_origin}#{path}"
  end

  private def self_url : String
    absolute_url(context.request.path)
  end

  private def project_item(project : Project) : RssFeed::Item
    RssFeed::Item.new(
      title: project.title,
      link: absolute_url("/p/#{project.slug}"),
      guid: "isho:project:#{project.id}",
      published_at: project.published_at || project.created_at,
      creator: project.user.name,
      description: project_description(project),
      categories: project.tags.map(&.name),
    )
  end

  private def project_description(project : Project) : String
    parts = [] of String

    if tagline = project.tagline.try(&.strip)
      parts << tagline unless tagline.empty?
    end

    excerpt = FeedText.excerpt(project.description)
    parts << excerpt unless excerpt.empty?

    parts.empty? ? "Проект на #{AppSettings::SITE_NAME}" : parts.join(" — ")
  end
end
