# Headers for things users uploaded. Browser builds must never run with the
# site's origin: a sandboxed document cannot read cookies, localStorage or the
# API on behalf of a signed-in visitor. Downloadable builds are always served
# as attachments so an uploaded .html cannot execute either.
class MediaHeadersHandler
  include HTTP::Handler

  SANDBOX = "sandbox allow-scripts allow-forms allow-pointer-lock allow-modals allow-popups allow-downloads"

  def call(context : HTTP::Server::Context)
    path = context.request.path
    headers = context.response.headers

    if path.starts_with?("/media/web/")
      headers["Content-Security-Policy"] = SANDBOX
      headers["X-Content-Type-Options"] = "nosniff"
      headers["Cross-Origin-Resource-Policy"] = "cross-origin"
      headers["Access-Control-Allow-Origin"] = "*"

      # A sandboxed game has an opaque origin, so its fetch() calls are
      # cross-origin. Answer the preflight instead of letting the static
      # handler reject OPTIONS with 405.
      if context.request.method == "OPTIONS"
        headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "*"
        context.response.status_code = 204
        return
      end
    elsif path.starts_with?("/media/build/")
      headers["Content-Disposition"] = "attachment"
      headers["Content-Security-Policy"] = "sandbox"
      headers["X-Content-Type-Options"] = "nosniff"
    end

    call_next(context)
  end
end
