# Rack Compatibility Extension

Backward compatibility with the [Rack specification](https://github.com/rack/rack/blob/master/SPEC.rdoc).

The following is the **normative specification**:

```ruby
# Version MUST match supported Rack spec version (e.g., [1, 3, 0] for Rack 1.3)
Server.extensions[:rack] = [1, 3, 0]

# Server MUST wrap Rack apps (those responding to call but not on_http) with adapter that:
#   1. Calls app.call(env) when request received
#   2. Handles Rack response [status, headers, body] per Rack spec
#   3. Sends response via NeoRack event API
#   4. Calls body.close if body responds to close
Server.instance_eval do
  class RackWrapper
    def initialize(app)
      @app = app
    end

    def on_http(e)
      status, headers, body = @app.call(e.env)
      e.status = status
      headers.each { |k, v| e.write_header(k, v) }
      body.each { |chunk| e.write(chunk) }
      e.finish
    ensure
      body.close if body.respond_to?(:close)
    end
  end

  RACK_LISTEN_OLD = method(:listen)

  def listen(url, handler, *args, &block)
    # Only wrap if handler lacks on_http but has call (Rack app)
    if !handler.respond_to?(:on_http) && handler.respond_to?(:call)
      handler = RackWrapper.new(handler)
    end
    RACK_LISTEN_OLD.call(url, handler, *args, &block)
  end
end

class Server::Event
  # Returns Rack-compliant env hash per Rack specification.
  # @return [Hash] env with all required Rack keys populated
  # MUST include all required Rack env keys (REQUEST_METHOD, PATH_INFO, etc.)
  # SHOULD use Event instance as rack.input (body IO)
  # MUST return fresh Hash instance for each call (apps MAY mutate env)
  def env; end

  # (OPTIONAL) Hijacks connection for raw socket access.
  # @return [IO, nil] IO-like object per Rack hijack extension, nil if unavailable
  # MAY be implemented; not required.
  # MUST return nil if called after headers sent (unless trailers supported).
  def rack_hijack; end
end
```

## Error Handling

Servers MUST return HTTP 500 Internal Server Error on uncaught exceptions from Rack applications.

## Implementation Notes

The Event object is designed to serve as `rack.input` (request body IO) in the env hash.
