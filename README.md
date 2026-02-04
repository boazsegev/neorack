# NeoRack

**A modern Ruby server-application specification designed for streaming, WebSockets, and async operations.**

NeoRack replaces Rack's CGI-based design with an event-driven API. Write Ruby web applications that stream responses, handle WebSocket connections, and manage Server-Sent Events—without workarounds or hacks.

```ruby
# A complete NeoRack application
module MyApp
  def self.on_http(e)
    e.write_header("content-type", "text/plain")
    e.finish("Hello, World!")
  end
end
# A familiar Rack style DSL
run MyApp
```

## Servers Supporting NeoRack

- [Iodine](https://github.com/boazsegev/iodine) (Rack/NeoRack support)

## Why NeoRack Instead of Rack?

Rack's CGI-based design requires your application to return a complete response array `[status, headers, body]` before the server can send anything. This creates friction for:

- **Streaming responses** — Rack needs workarounds like `rack.hijack`
- **WebSocket connections** — Requires non-standard extensions
- **Server-Sent Events** — No native support
- **Async operations** — Blocking model limits concurrency
- **Performance** — Avoiding Rack's `HTTP_` header prefix minimizes allocations and String manipulations (memory and CPU cycles), resulting in better performance.

NeoRack's event-driven design handles these natively:

```ruby
module StreamingApp
  def self.on_http(e)
    e.write_header("content-type", "text/event-stream")
    
    # Stream data as it becomes available
    e.write("data: First chunk\n\n")
    e.write("data: Second chunk\n\n")
    e.finish("data: Done\n\n")
  end
end
```
## Why Rack Instead of NeoRack?

- **Backwards Compatibility** — Rack has a lot of useful existing code.
- **Fibers** (instead of Threads) — Fibers can mitigate some of Rack's CGI approach (see [Falcon](https://github.com/socketry/falcon)).

## Key Features

- **Event-driven API** — Call `e.write` multiple times, finish when ready
- **Native streaming** — No hijacking or workarounds needed
- **WebSocket support** — (extension) Built into the specification via extensions
- **SSE support** — (extension) Server-Sent Events as a first-class feature
- **Pub/Sub built-in** — (extension) Subscribe and publish across connections
- **Rack compatibility** — (extension) Host existing Rack apps inside NeoRack applications
- **Thread-safe by design** — Clear guidelines for concurrent request handling

## Documentation

| Document | Description |
|----------|-------------|
| [**SPEC.md**](./SPEC.md) | Full protocol specification |
| [**Extensions**](./extensions/) | WebSockets, SSE, Pub/Sub, Cookies, Rack compatibility |
| [**Example App**](./example/) | Working application demonstrating NeoRack patterns |

## Application Structure

A NeoRack application is any Ruby object responding to `on_http`:

```ruby
module MyApp
  # Required: Called for every HTTP request
  def self.on_http(e)
    e.finish("Response body")
  end

  # Optional: Called after response completes (cleanup)
  def self.on_finish(e)
    # Log, cleanup resources, etc.
  end
end
```

The event object `e` provides:

- **Request data** — `e.method`, `e.path`, `e.query`, `e["header-name"]`
- **Response control** — `e.status=`, `e.write_header`, `e.write`, `e.finish`
- **Body reading** — `e.read`, `e.gets`, `e.length`
- **Key-value storage** — `e[:my_data]` for middleware communication

## Middleware

```ruby
class AuthMiddleware
  def initialize(app)
    @app = app
  end

  def on_http(e)
    if authorized?(e)
      @app.on_http(e)
    else
      e.status = 401
      e.finish("Unauthorized")
    end
  end

  def on_finish(e)
    @app.on_finish(e) if @app.respond_to?(:on_finish)
  end
end
```

## Configuration (config.nru)

```ruby
use AuthMiddleware
use LoggingMiddleware

map '/api' do
  run ApiApp
end

map '/admin' do
  use AdminAuthMiddleware
  run AdminApp
end

run MainApp
```

## Rack Compatibility

NeoRack applications can host Rack applications, allowing gradual migration:

```ruby
# Wrap a Rack app for use in NeoRack
rack_app = Rack::Builder.app do
  use Rack::CommonLogger
  run MyLegacyRackApp
end

# NeoRack servers with :rack extension can run this
run rack_app
```

## Status

NeoRack is an evolving specification. The core API is stabilizing, but breaking changes may occur and we are excited to get your input.

## Background

Rack's limitations have been [documented since 2012](http://blog.plataformatec.com.br/2012/06/why-your-web-framework-should-not-adopt-rack-api/). Previous attempts to modernize Ruby's server-application interface ([Rack-Next](https://github.com/Wardrop/Rack-Next), [The Metal](https://github.com/tenderlove/the_metal)) didn't gain adoption.

NeoRack takes a different approach: rather than extending Rack, it provides a clean specification built on lessons learned from over a decade of Ruby web development.
