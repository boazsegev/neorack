# From Extension

Extension for discovering the claimed source address of a request (proxy-aware).

The following is the **normative specification**:

```ruby
Server.extensions[:from] = [0, 0, 2]

class Server::Event
  # Returns the claimed source address of the request.
  # @return [String, nil] IP address string (IPv4 or IPv6, without brackets or port)
  # Resolution order (MUST follow):
  #   1. `for` property in `Forwarded` header (RFC 7239)
  #   2. Leftmost address in `X-Forwarded-For` header (original client IP)
  #      e.g., "X-Forwarded-For: client, proxy1, proxy2" → return "client"
  #   3. e.peer_addr (direct connection)
  # MUST strip IPv6 brackets and port if present (e.g., "[::1]:8080" -> "::1")
  # SHOULD return nil if header value is malformed
  def from; end
end
```

## Security Considerations

**WARNING**: The `Forwarded` and `X-Forwarded-For` headers can be spoofed by clients.

| Risk | Mitigation |
|------|------------|
| IP spoofing | Applications MUST NOT trust `from` for security decisions unless behind a trusted proxy |
| Header injection | Servers SHOULD validate header format before parsing |
| Trusted proxies | Applications SHOULD configure trusted proxy IPs and only trust forwarded headers from those sources |

For security-sensitive use cases (rate limiting, access control), applications SHOULD use `e.peer_addr` directly or implement trusted proxy validation.
