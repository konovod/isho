# Serves pre-compressed files of browser builds requested by their literal
# name, the way Unity asks for them when "Decompression Fallback" is off (the
# default): `Build/Game.framework.js.br` arrives with `Content-Encoding: br`
# and the media type of `Game.framework.js`, so the browser decompresses the
# body itself and only then runs the script.
#
# Lucky::StaticFileHandler cannot do that: `.br` is not a known extension, so
# it answers `application/octet-stream`, and with `X-Content-Type-Options:
# nosniff` the browser refuses to execute the framework at all. The same goes
# for `application/wasm`, without which streaming compilation is skipped.
class WebBuildAssetsHandler
  include HTTP::Handler

  PREFIX    = "/media/web/"
  ENCODINGS = {
    ".br" => "br",
    ".gz" => "gzip",
  }

  def initialize(@root : String = BuildStorage::WEB_DIRECTORY)
    @root = File.expand_path(@root)
  end

  def call(context : HTTP::Server::Context)
    path = context.request.path
    return call_next(context) unless context.request.method.in?("GET", "HEAD")
    return call_next(context) unless path.starts_with?(PREFIX)

    suffix = ENCODINGS.keys.find { |candidate| path.ends_with?(candidate) }
    return call_next(context) unless suffix

    decoded = URI.decode(path)
    file_path = resolve(decoded)
    return call_next(context) unless file_path

    serve(context, file_path, decoded.rchop(suffix), ENCODINGS[suffix])
  end

  # `..` in the URL must not reach anything outside the builds directory.
  private def resolve(decoded : String) : String?
    relative = decoded.lchop(PREFIX)
    return nil if relative.empty?

    full = File.expand_path(File.join(@root, relative))
    return nil unless full.starts_with?(@root + '/') || full.starts_with?(@root + '\\')
    return nil unless File.file?(full)

    full
  end

  private def serve(
    context : HTTP::Server::Context,
    file_path : String,
    original_name : String,
    encoding : String,
  ) : Nil
    info = File.info?(file_path)
    return call_next(context) unless info

    response = context.response
    size = info.size

    response.headers["Content-Encoding"] = encoding
    response.headers["Accept-Ranges"] = "bytes"
    response.headers["Etag"] = etag(info)
    response.headers["Last-Modified"] = HTTP.format_time(info.modification_time)
    response.content_type = MIME.from_filename(original_name, "application/octet-stream")

    if not_modified?(context, info)
      response.status = :not_modified
      return
    end

    case range = range_for(context, size)
    when Symbol
      response.status = :range_not_satisfiable
      response.headers["Content-Range"] = "bytes */#{size}"
      response.content_length = 0
    when Tuple(Int64, Int64)
      first, last = range
      response.status = :partial_content
      response.headers["Content-Range"] = "bytes #{first}-#{last}/#{size}"
      response.content_length = last - first + 1
      return if context.request.method == "HEAD"

      File.open(file_path) do |file|
        file.seek(first)
        IO.copy(file, response, last - first + 1)
      end
    else
      response.content_length = size
      return if context.request.method == "HEAD"

      File.open(file_path) { |file| IO.copy(file, response) }
    end
  rescue File::Error
    # The file vanished between the stat and the open; the connection is
    # dropped instead of answering with a half-written body.
  end

  private def etag(info : File::Info) : String
    %{W/"#{info.modification_time.to_unix}-#{info.size}"}
  end

  private def not_modified?(context : HTTP::Server::Context, info : File::Info) : Bool
    if if_none_match = context.request.headers["If-None-Match"]?
      if_none_match.split(',').any? { |value| value.strip == etag(info) }
    elsif header = context.request.headers["If-Modified-Since"]?
      since = HTTP.parse_time(header)
      !!(since && info.modification_time <= since + 1.second)
    else
      false
    end
  end

  # A single byte range, `:unsatisfiable` or `nil` when the header is absent or
  # in a form worth ignoring (browsers then get the whole file, as allowed).
  private def range_for(context : HTTP::Server::Context, size : Int64) : {Int64, Int64}? | Symbol
    header = context.request.headers["Range"]?
    return nil unless header

    match = header.strip.match(/\Abytes=(\d*)-(\d*)\z/)
    return nil unless match

    first_part, last_part = match[1], match[2]
    return nil if first_part.empty? && last_part.empty?

    if first_part.empty?
      suffix = last_part.to_i64?
      return nil unless suffix
      return :unsatisfiable if suffix <= 0 || size <= 0

      first = {size - suffix, 0_i64}.max
      last = size - 1
    else
      first = first_part.to_i64?
      return nil unless first
      last = last_part.empty? ? size - 1 : last_part.to_i64?.try { |value| {value, size - 1}.min }
      return nil unless last
    end

    return :unsatisfiable if first >= size || first > last

    {first, last}
  end
end
