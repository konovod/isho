# Caddy asks this before issuing a certificate for a hostname it sees for the
# first time (`on_demand_tls` in deploy/server/Caddyfile). Only hosts of
# existing projects under the media origin are allowed, so the server never
# issues certificates for arbitrary names.
#
# The route is outside `/api` on purpose: Caddy reaches the API directly on
# 127.0.0.1 and never proxies this path to the internet.
class Internal::Tls::Allow < ApiAction
  include Api::Auth::SkipRequireSession

  get "/internal/tls/allow" do
    if allowed?(params.get?(:domain) || "")
      head 200
    else
      head 403
    end
  end

  private def allowed?(domain : String) : Bool
    host = domain.strip.downcase
    base = MediaOrigin.host
    return false unless base && host.ends_with?(".#{base}")

    label = host[0, host.size - base.size - 1]
    return false if label.empty? || label.includes?('.')
    return false unless label.matches?(/\A[a-z0-9-]+\z/)

    !!ProjectQuery.new.slug(label).first?
  end
end
