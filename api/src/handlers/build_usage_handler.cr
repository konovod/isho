# Counts what visitors do with hosted builds: a file build is downloaded and a
# browser build is launched by opening its entry page.
#
# Static files are served after this handler, so the counters are written while
# the request is still on its way to the file. A failure to write a counter must
# never break the download, hence the rescue.
class BuildUsageHandler
  include HTTP::Handler

  FILE_PATH = /\A\/media\/(build\/([A-Za-z0-9-]+)\/files\/.+)\z/
  WEB_PATH  = /\A\/media\/web\/([A-Za-z0-9-]+)\/(.+)\z/

  PAGE_SUFFIXES = {".html", ".htm"}

  def call(context : HTTP::Server::Context)
    begin
      record(context)
    rescue error
      Log.warn(exception: error) { "Build usage was not counted" }
    end

    call_next(context)
  end

  private def record(context : HTTP::Server::Context) : Nil
    request = context.request
    return unless request.method == "GET"

    path = URI.decode(request.path)

    if path.starts_with?("/media/build/")
      record_download(request, path)
    elsif path.starts_with?("/media/web/")
      record_launch(context, path)
    end
  end

  private def record_download(request : HTTP::Request, path : String) : Nil
    match = FILE_PATH.match(path)
    return unless match
    return if resuming?(request)

    # `stored_file->>'id'` is the path Latch reports as the URL, so a request
    # for a name that does not belong to the build is ignored.
    BuildUsage.download(match[2], match[1])
  end

  private def record_launch(context : HTTP::Server::Context, path : String) : Nil
    match = WEB_PATH.match(path)
    return unless match

    entry = match[2]
    return unless page?(entry)

    # A browser may keep the entry page in its heuristic cache and never ask
    # again, which would hide every later launch. Revalidating an HTML page is
    # cheap: unchanged files are answered with 304, and that request still
    # counts.
    context.response.headers["Cache-Control"] = "no-cache"

    BuildUsage.launch(match[1], entry)
  end

  # The first request of a download has no Range header, or asks for the whole
  # file from the first byte. A resumed or suffix range is the same download
  # continuing, not another one.
  private def resuming?(request : HTTP::Request) : Bool
    range = request.headers["Range"]?
    return false unless range

    !range.strip.starts_with?("bytes=0-")
  end

  private def page?(path : String) : Bool
    downcased = path.downcase
    PAGE_SUFFIXES.any? { |suffix| downcased.ends_with?(suffix) }
  end
end
