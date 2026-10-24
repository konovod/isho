# Headers for things users uploaded. Browser builds must never run with the
# site's origin: a sandboxed document cannot read cookies or the API on behalf
# of a signed-in visitor. Downloadable builds are always served as attachments
# so an uploaded .html cannot execute either.
class MediaHeadersHandler
  include HTTP::Handler

  SANDBOX = "sandbox allow-scripts allow-forms allow-pointer-lock allow-modals allow-popups allow-downloads"

  # A game needs Cache Storage, IndexedDB and localStorage (Unity keeps its
  # build cache and PlayerPrefs there), and an opaque origin has none of them.
  # Keeping its own origin is safe only on the dedicated media host, where no
  # session cookie and nothing of the site exists, so the flag is added only
  # there and never on the app origin.
  SANDBOX_SAME_ORIGIN = "#{SANDBOX} allow-same-origin"

  def call(context : HTTP::Server::Context)
    path = context.request.path
    headers = context.response.headers

    if path.starts_with?("/media/web/")
      headers["Content-Security-Policy"] = sandbox_policy(context)
      headers["X-Content-Type-Options"] = "nosniff"
      headers["Cross-Origin-Resource-Policy"] = "cross-origin"
      headers["Access-Control-Allow-Origin"] = "*"

      # A game on the app origin is sandboxed into an opaque origin, so its
      # fetch() calls are cross-origin. Answer the preflight instead of letting
      # the static handler reject OPTIONS with 405.
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

  private def sandbox_policy(context : HTTP::Server::Context) : String
    media_host = AppSettings.media_host
    if media_host && context.request.hostname == media_host
      SANDBOX_SAME_ORIGIN
    else
      SANDBOX
    end
  end
end
