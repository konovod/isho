require "socket"
require "uri"

# Decides whether the server may fetch an address for an author.
#
# The rule is "public http(s) only", checked on the address that DNS actually
# returns and on every redirect: a public hostname may point at 127.0.0.1, at
# the cloud metadata service or at the office LAN. The lookup and the connection
# are separate DNS answers, so a rebinding attacker keeps a theoretical window;
# an import only ever produces a draft for the author to review, which is why
# that residual risk is acceptable here.
module Import::UrlGuard
  class Blocked < Import::Failed; end

  ALLOWED_PORTS   = [80, 443]
  ALLOWED_SCHEMES = %w[http https]
  LOOKUP_TIMEOUT  = 5.seconds

  # The suite replaces this, so specs never ask DNS. Production keeps the real
  # lookup, which is the only place a host name becomes an address.
  class_property resolver : Proc(String, Int32, Array(Socket::IPAddress)) = ->(host : String, port : Int32) { Import::UrlGuard.resolve(host, port) }

  def self.parse(raw : String) : URI
    URI.parse(raw.strip)
  rescue URI::Error
    raise Blocked.new("ссылка не разобрана")
  end

  # Parses and checks in one go. Raises `Blocked` with a reason a person can read.
  def self.check(raw : String) : URI
    uri = parse(raw)
    check!(uri)
    uri
  end

  def self.check!(uri : URI) : Nil
    scheme = uri.scheme.to_s.downcase
    unless ALLOWED_SCHEMES.includes?(scheme)
      raise Blocked.new("поддерживаются только ссылки http и https")
    end

    host = uri.host.to_s.strip
    raise Blocked.new("в ссылке нет адреса") if host.empty?
    raise Blocked.new("ссылка с логином не поддерживается") if uri.user || uri.password

    port = uri.port || (scheme == "https" ? 443 : 80)
    unless ALLOWED_PORTS.includes?(port)
      raise Blocked.new("порт #{port} не поддерживается")
    end

    addresses(host, port).each do |ip|
      raise Blocked.new("адрес #{host} ведёт во внутреннюю сеть") if internal?(ip)
    end
  end

  # Resolves a host once and returns its addresses, so callers that also want to
  # connect do not ask DNS twice for the same decision.
  def self.addresses(host : String, port : Int32) : Array(Socket::IPAddress)
    resolver.call(host, port)
  rescue error : Blocked
    raise error
  rescue error
    raise Blocked.new("не удалось определить адрес #{host}")
  end

  def self.resolve(host : String, port : Int32) : Array(Socket::IPAddress)
    Socket::Addrinfo.tcp(host, port, timeout: LOOKUP_TIMEOUT).map(&.ip_address)
  rescue error : Socket::Error | IO::TimeoutError | RuntimeError
    raise Blocked.new("не удалось определить адрес #{host}")
  end

  def self.internal?(ip : Socket::IPAddress) : Bool
    return true if ip.loopback? || ip.private? || ip.link_local? || ip.unspecified?

    address = ip.address

    # IPv4-mapped IPv6 (`::ffff:10.0.0.1`) slips past the ranges above.
    if address.starts_with?("::ffff:")
      return v4_internal?(address.lchop("::ffff:"))
    end

    if address.includes?(':')
      address.starts_with?("ff") # ff00::/8
    else
      v4_internal?(address)
    end
  end

  private def self.v4_internal?(address : String) : Bool
    parts = address.split('.')
    return true unless parts.size == 4

    bytes = parts.map { |part| part.to_i? || -1 }
    return true if bytes.any? { |value| value < 0 || value > 255 }

    first = bytes[0]
    second = bytes[1]

    first == 0 ||                                        # 0.0.0.0/8
      first == 10 ||                                     # 10.0.0.0/8
      first == 127 ||                                    # 127.0.0.0/8
      (first == 172 && second >= 16 && second <= 31) ||  # 172.16.0.0/12
      (first == 192 && second == 168) ||                 # 192.168.0.0/16
      (first == 169 && second == 254) ||                 # 169.254.0.0/16
      (first == 100 && second >= 64 && second <= 127) || # 100.64.0.0/10
      (first == 192 && second == 0) ||                   # 192.0.0.0/24
      first >= 224                                       # multicast and reserved
  end
end
