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

run MyApp
```

---

## Getting Started

### Installation

NeoRack requires a compatible server. Currently supported:

- [Iodine](https://github.com/boazsegev/iodine) — High-performance HTTP/WebSocket server with Rack and NeoRack support

```bash
gem install iodine
```

### Your First Application

Create `config.nru` and run with `iodine`:

```ruby
# config.nru
module MyApp
  def self.on_http(e)
    e.finish("Hello from NeoRack!")
  end
end

run MyApp
```

```bash
iodine
# => Server listening on http://localhost:3000
```

---

## Why NeoRack?

Rack's CGI-based design requires your application to return a complete response array `[status, headers, body]` before the server can send anything. This creates friction for:

- **Streaming responses** — Rack needs workarounds like `rack.hijack`
- **WebSocket connections** — Requires non-standard extensions
- **Server-Sent Events** — No native support
- **Async operations** — Blocking model limits concurrency
- **Performance** — Avoiding Rack's `HTTP_` header prefix minimizes allocations and String manipulations

NeoRack's event-driven design handles these natively.

**When to stick with Rack:** If you rely heavily on existing Rack middleware, or use Fiber-based servers like [Falcon](https://github.com/socketry/falcon), Rack may still be the right choice.

### Features at a Glance

| Feature | Description |
|---------|-------------|
| **Event-driven API** | Call `e.write` multiple times, finish when ready |
| **Native streaming** | No hijacking or workarounds needed |
| **WebSocket support** | WebSockets as first-class citizens (extension) |
| **SSE support** | Server-Sent Events as first-class citizens (extension) |
| **Pub/Sub built-in** | Subscribe and publish across connections (extension) |
| **REST resources** | Convention-based CRUD routing (extension) |
| **Cookies** | Simple cookie API with security options (extension) |
| **Rack compatibility** | Host existing Rack apps (extension) |

---

## Core Concepts

Every NeoRack application implements `on_http(e)`. The event object `e` gives you access to the request and control over the response.

### Basic Application

```ruby
module MyApp
  def self.on_http(e)
    e.finish("Response body")
  end

  # Optional: cleanup after response completes
  def self.on_finish(e)
    # Log, release resources, etc.
  end
end
```

### The Event Object

Access request data and build your response through the event object:

```ruby
module InspectorApp
  def self.on_http(e)
    # Request information
    info = [
      "Method:  #{e.method}",
      "Path:    #{e.path}",
      "Query:   #{e.query}",
      "Body:    #{e.length} bytes"
    ]
    
    # Access headers with lowercase string keys
    info << "Host: #{e['host']}" if e['host']
    
    # Iterate all headers
    e.headers.each do |key, value|
      next unless key.is_a?(String)  # skip app data (symbols)
      info << "#{key}: #{value}"
    end
    
    e.write_header("content-type", "text/plain")
    e.finish(info.join("\n"))
  end
end
```

### Key-Value Storage

The event object doubles as key-value storage. Use **symbols** for application data and **strings** for HTTP headers:

```ruby
module MyApp
  def self.on_http(e)
    # Middleware may have set :current_user
    user = e[:current_user]
    e.finish(user ? "Hello, #{user[:name]}!" : "Hello, guest!")
  end
end
```

---

## Streaming Responses

Send data to the client as it becomes available—no buffering required:

```ruby
module StreamingApp
  def self.on_http(e)
    e.write_header("content-type", "text/plain")
    
    # Each write sends data immediately
    e.write("Processing started...\n")
    e.write("Step 1 complete\n")
    e.write("Step 2 complete\n")
    e.finish("Done!\n")
  end
end
```

---

## WebSocket Support

NeoRack treats WebSockets as first-class citizens. Implement `on_authenticate_websocket` to accept connections, then handle messages with `on_message`.

### Basic WebSocket

For simple use cases, accept all connections and handle messages directly:

```ruby
module EchoApp
  def self.on_authenticate_websocket(e)
    true  # Accept all connections
  end

  def self.on_open(e)
    e.write("Connected!")
  end

  def self.on_message(e, msg)
    e.write("You said: #{msg}")
  end

  def self.on_close(e)
    # Cleanup handled automatically
  end
end
```

Client-side:

```javascript
const ws = new WebSocket("ws://localhost:3000/echo");
ws.onmessage = (e) => console.log(e.data);
ws.onopen = () => ws.send("Hello!");
```

### WebSocket with Authentication

For production applications, authenticate connections using signed session tokens:

```ruby
module ChatApp
  # Helper: Create a signed session token (call this at login)
  def self.create_session_token(user_id, expires_at = Time.now.to_i + 86400)
    # Build payload: user_id|expiration_timestamp
    payload = "#{user_id}|#{expires_at}"
    # Sign with server secret using HMAC-SHA256
    signature = Iodine::Utils.hmac256(Iodine.secret, payload)
    # Return URL-safe token: payload.signature
    "#{payload}.#{signature}"
  end

  # Helper: Verify and extract user_id from signed token
  def self.verify_session_token(token)
    return nil unless token&.include?(".")

    # Split into payload and signature
    payload, signature = token.rpartition(".").values_at(0, 2)
    return nil if payload.empty? || signature.nil?

    # Verify signature using timing-safe comparison
    expected = Iodine::Utils.hmac256(Iodine.secret, payload)
    return nil unless Iodine::Utils.secure_compare(signature, expected)

    # Parse payload and check expiration
    user_id, expires_at = payload.split("|", 2)
    return nil if expires_at.to_i < Time.now.to_i

    user_id
  end

  def self.on_authenticate_websocket(e)
    # Read the session cookie (contains signed token)
    token = e.cookie("session")
    
    # Verify signature and extract user_id (returns nil if invalid/expired)
    user_id = verify_session_token(token)
    return false unless user_id

    # Store verified user_id for use in other callbacks
    e[:user_id] = user_id

    # Update token's expiration timestamp
    token = ChatApp.create_session_token(user.id)
    e.set_cookie("session", value: token, http_only: true, secure: true, same_site: :strict)
    
    true
  end

  def self.on_open(e)
    e.subscribe("chat:lobby")
    e.write({ type: "welcome", user: e[:user_id] })
  end

  def self.on_message(e, msg)
    # Publish to all subscribers except sender
    e.publish("chat:lobby", msg)
  end

  def self.on_close(e)
    # Cleanup handled automatically
  end
end

# At login, set the signed session cookie:
#   token = ChatApp.create_session_token(user.id)
#   e.set_cookie("session", value: token, http_only: true, secure: true, same_site: :strict)
```

---

## Server-Sent Events (SSE)

SSE provides one-way server-to-client streaming over HTTP—ideal for live updates, notifications, and dashboards:

```ruby
module LiveUpdates
  def self.on_authenticate_sse(e)
    true  # Accept all SSE connections
  end

  def self.on_open(e)
    e.subscribe("updates")
  end

  def self.on_eventsource_reconnect(e, last_id)
    # Client reconnected—replay missed events if needed
  end
end

# Elsewhere in your app, push updates:
Server.publish("updates", { price: 42.50 }.to_json)
```

Client-side:

```javascript
const events = new EventSource("/live");
events.onmessage = (e) => console.log(JSON.parse(e.data));
```

---

## Pub/Sub Messaging

Broadcast messages across connections and processes. Works with both WebSocket and SSE:

```ruby
module NotificationApp
  def self.on_open(e)
    # Subscribe with custom handler
    e.subscribe("alerts") do |msg|
      e.write_sse(msg.id, "alert", msg.message)
    end
    
    # Or use default behavior (writes msg.message directly)
    e.subscribe("broadcasts")
  end

  def self.on_message(e, msg)
    # Publish to everyone except sender
    e.publish("broadcasts", msg)
    
    # Publish to everyone including sender
    Server.publish("broadcasts", msg)
  end
end
```

---

## REST Resources

Map HTTP methods to resource actions automatically. Define only the actions you need:

```ruby
module UsersResource
  def self.index(e)   # GET /users
    e.finish(User.all.to_json)
  end

  def self.show(e)    # GET /users/:id
    id = e.path[1..-1]
    e.finish(User.find(id).to_json)
  end

  def self.new(e)     # GET /users/new
    e.finish(render_form)
  end

  def self.create(e)  # POST /users
    data = JSON.parse(e.read)
    user = User.create(data)
    e.status = 201
    e.finish(user.to_json)
  end

  def self.edit(e)    # GET /users/:id/edit
    id = e.path.split('/')[1]
    e.finish(render_form(User.find(id)))
  end

  def self.update(e)  # PUT/PATCH /users/:id
    id = e.path[1..-1]
    data = JSON.parse(e.read)
    User.update(id, data)
    e.finish
  end

  def self.delete(e)  # DELETE /users/:id
    id = e.path[1..-1]
    User.destroy(id)
    e.status = 204
    e.finish
  end
end

# In config.nru:
neorack_resource UsersResource
map '/users', UsersResource
```

---

## Cookies

Read and set cookies with built-in security options:

```ruby
module SessionApp
  def self.on_http(e)
    # Read cookies
    session_id = e.cookie("session")
    
    if session_id
      e.finish("Welcome back!")
    else
      # Set a secure session cookie
      e.set_cookie("session",
        value:     SecureRandom.hex(32),
        max_age:   86400 * 30,  # 30 days
        path:      "/",
        http_only: true,
        secure:    true,
        same_site: :lax
      )
      e.finish("Session created!")
    end
  end
end
```

---

## Middleware

Wrap applications to add cross-cutting concerns like logging, authentication, or timing:

```ruby
class TimingMiddleware
  def initialize(app)
    @app = app
  end

  def on_http(e)
    e[:request_started] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @app.on_http(e)
  end

  def on_finish(e)
    if e[:request_started]
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - e[:request_started]
      puts "#{e.method} #{e.path} completed in #{(duration * 1000).round(2)}ms"
    end
    @app.on_finish(e) if @app.respond_to?(:on_finish)
  end

  # Delegate unknown methods to the wrapped app
  def method_missing(name, *args, &block)
    @app.send(name, *args, &block)
  end

  def respond_to_missing?(name, include_private = false)
    @app.respond_to?(name, include_private)
  end
end
```

---

## Configuration (config.nru)

The `config.nru` file defines your application's routing and middleware stack:

```ruby
# Middleware applies to all routes below
use TimingMiddleware
use AuthMiddleware

# Route-specific configuration
map '/api' do
  use RateLimitMiddleware
  run ApiApp
end

map '/admin' do
  use AdminAuthMiddleware
  run AdminApp
end

map '/ws', ChatApp

# Default handler
run MainApp
```

---

## Rack Compatibility

Migrate gradually by running existing Rack applications alongside NeoRack code:

```ruby
# Servers with the :rack extension auto-wrap Rack apps
rack_app = Rack::Builder.app do
  use Rack::CommonLogger
  run MyLegacyRackApp
end

run rack_app
```

Or create a hybrid application:

```ruby
module HybridApp
  # NeoRack handler for modern features
  def self.on_http(e)
    e.finish("NeoRack response")
  end

  # Rack handler for compatibility
  def self.call(env)
    [200, { "content-type" => "text/plain" }, ["Rack response"]]
  end
end
```

---

## Server Lifecycle

Hook into server events for initialization and cleanup:

```ruby
Server.on_state(:start) do
  puts "Worker #{Process.pid} started"
  # Initialize connections, warm caches, etc.
end

Server.on_state(:start_shutdown) do
  puts "Shutting down..."
  # Begin graceful shutdown
end

Server.on_state(:stop) do
  # Final cleanup
end
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [**SPEC.md**](./SPEC.md) | Full protocol specification |
| [**Extensions**](./extensions/) | WebSockets, SSE, Pub/Sub, Cookies, REST, Rack |
| [**Example App**](./example/) | Working application demonstrating NeoRack patterns |

---

## Status & Background

NeoRack is an evolving specification. The core API is stabilizing, but breaking changes may occur. We welcome your input!

Rack's limitations have been [documented since 2012](http://blog.plataformatec.com.br/2012/06/why-your-web-framework-should-not-adopt-rack-api/). Previous attempts to modernize Ruby's server-application interface ([Rack-Next](https://github.com/Wardrop/Rack-Next), [The Metal](https://github.com/tenderlove/the_metal)) didn't gain adoption. NeoRack takes a different approach: rather than extending Rack, it provides a clean specification built on lessons learned from over a decade of Ruby web development.

---
