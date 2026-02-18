# Cookies Extension

Extension for cookie access and management in NeoRack applications.

The following is the **normative specification**:

```ruby
Server.extensions[:cookies] = [0, 0, 2]

class Server::Event
  # Returns the value of a cookie by name.
  # @param name [String] cookie name (MUST be valid cookie-name per RFC 6265)
  # @return [String, nil] ASCII-8BIT encoded value, or nil if not found
  # Cookies set via set_cookie (that returned true) MUST be accessible here.
  def cookie(name); end

  # Iterates over all cookies (received + successfully set).
  # @yield [name, value] for each cookie
  # @return [self]
  # MUST include cookies set via set_cookie that returned true.
  def each_cookie(&block); end

  # Sets a cookie. Returns true on success, false if headers already sent.
  # @param name [String] cookie name (MUST be valid cookie-name per RFC 6265)
  # @param value [String, nil] cookie value; nil = delete cookie
  # @param max_age [Integer, nil] seconds until expiry:
  #     nil (or 0) = session cookie (deleted when browser closes)
  #     N < 0      = delete cookie immediately (expires in past)
  #     N > 0      = expire in N seconds
  # @param domain [String, nil] cookie domain
  # @param path [String, nil] cookie path
  # @param same_site [Symbol, nil] MUST support: :none, :lax, :strict
  #   nil = omit SameSite attribute (browser default, typically Lax)
  # @param secure [Boolean] HTTPS only
  # @param http_only [Boolean] inaccessible to JavaScript
  # @param partitioned [Boolean] partitioned cookie (CHIPS)
  # @return [Boolean] true on success, false if headers already sent
  # Cookie MUST be accessible via cookie() method after successful set.
  # SHOULD accept keyword arguments: set_cookie(name: "x", value: "y", max_age: 3600)
  # Server SHOULD NOT modify name/value; if it does, MUST auto-reverse on read.
  # See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie
  def set_cookie(name, value = nil, max_age = nil, domain = nil, path = nil,
                 same_site = nil, secure = false, http_only = false,
                 partitioned = false); end
end
```

## Implementation Notes

Implementers **SHOULD** support all [`Set-Cookie`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie) features, adding parameters as needed.
