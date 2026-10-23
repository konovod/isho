# Replaces Lucky::MaximumRequestSizeHandler, which reads the whole body into
# memory before routing. Upload chunks are capped by their declared length and
# guarded while streaming, so memory stays flat.
class RequestSizeLimitHandler
  include HTTP::Handler

  DEFAULT_LIMIT = 12_000_000_i64
  UPLOAD_LIMIT  = AppSettings::UPLOAD_CHUNK_BYTES + 1_000_000_i64

  class BodyTooLarge < Exception
  end

  def call(context : HTTP::Server::Context)
    limit = limit_for(context.request)

    if length = context.request.headers["Content-Length"]?.try(&.to_i64?)
      return too_large(context) if length > limit
    end

    if body = context.request.body
      context.request.body = LimitedBody.new(body, limit)
    end

    call_next(context)
  rescue BodyTooLarge
    too_large(context)
  end

  private def limit_for(request : HTTP::Request) : Int64
    path = request.path
    if path.starts_with?("/api/v1/projects/") && path.includes?("/uploads/")
      UPLOAD_LIMIT
    else
      DEFAULT_LIMIT
    end
  end

  private def too_large(context : HTTP::Server::Context)
    context.response.status_code = 413
    context.response.content_type = "application/json"
    context.response.print ErrorSerializer.new(
      code: "file_too_large",
      message: "The request body is too large",
    ).to_json
  end

  # Counts bytes while they stream through. Reading a body that lies about its
  # length (or uses chunked encoding) stops here instead of growing a String.
  class LimitedBody < IO
    def initialize(@body : IO, @limit : Int64)
      @read = 0_i64
    end

    def read(slice : Bytes) : Int32
      count = @body.read(slice)
      @read += count
      raise BodyTooLarge.new if @read > @limit

      count
    end

    def write(slice : Bytes) : Nil
      raise IO::Error.new("Request bodies are read-only")
    end
  end
end
