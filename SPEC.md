# NeoRack - A New Server-Application Bridge Protocol

**Protocol Specification Version:** `0.0.3` (`[0, 0, 3]`)

> The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", 
> "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and 
> "OPTIONAL" in this document are to be interpreted as described in 
> BCP 14 [RFC2119] [RFC8174] when, and only when, they appear in all 
> capitals, as shown here.

This specification lists the requirements for NeoRack-compatible **Servers**, **Applications**, and **Middleware**.

## Terminology

- **Event class** (`Server::Event`): The class from which event instances are created.
- **event** (`e`): An instance representing a single HTTP request/response cycle.
- **handler**: The application or middleware chain that processes requests.

## NeoRack Applications

A NeoRack application is a Ruby object, singleton class, or module. The following is the **normative specification**:

```ruby
# A NeoRack application with all core callbacks.
# Applications MUST respond to on_http. MAY respond to on_finish.
module ExampleApp
  # (REQUIRED) Called for every HTTP request with a unique event instance.
  # Applications MUST call e.finish for every event (MAY be after on_http returns).
  def self.on_http(e) ; end

  # (OPTIONAL) Called for cleanup AFTER BOTH:
  #   1. e.finish was called (response finalized)
  #   2. on_http has returned
  # With WebSocket/SSE extensions: called after on_close, not after on_authenticate.
  def self.on_finish(e) ; end
end
```

### Threading Contract

| Rule | Requirement |
|------|-------------|
| Concurrent events | Different events MAY be processed concurrently |
| Single-thread per event | Same event MUST NOT be accessed from multiple threads |
| on_finish timing | Servers MUST NOT call on_finish until on_http returns |
| Thread safety | Apps SHOULD be thread-safe; SHOULD NOT use global/instance mutable state |

## NeoRack Servers

NeoRack servers **MUST** support this specification and **MAY** support any extensions they see fit.

NeoRack servers **MUST** support at least one NeoRack application per server instance and **MAY** support multiple applications concurrently (e.g., by listening to multiple sockets or implementing a routing layer).

## The `Server` Object

Servers MUST map the `Server` constant to the module/class implementing this API. MAY overwrite if already defined.

The following is the **normative specification**:

```ruby
module Server
  # MUST include :neo_rack key with spec version. Keys MUST be Symbols.
  # Values MUST be semver arrays (e.g., [0, 1, 0, "alpha", 1] for "0.1.0-alpha.1")
  def self.extensions; @extensions ||= { neo_rack: [0, 0, 3] } ; end

  # Configures server to listen on url and route requests to handler.
  # @param url [String, nil] URL format (e.g., "https://localhost:3000", "unix://./sock")
  #   nil -> server SHOULD use reasonable default
  #   Servers MAY process url freely (ignore path, parse scheme for TLS, etc.)
  # @param handler - MUST be a valid NeoRack application
  # Servers MAY support multiple listen() calls for multiple addresses.
  def self.listen(url, handler); end

  # Registers callback for server state changes. Multiple calls allowed per state.
  # @param state [Symbol] MUST support: :start, :start_shutdown, :stop (MAY add others)
  #   :start          - worker starting (non-forking: master enters after Server.start)
  #   :start_shutdown - current process shutting down
  #   :stop           - server in current process stopped
  # @param block [Proc] MUST NOT take arguments
  def self.on_state(state, &block); end

  # Thread count for concurrent on_http calls. 0 = single-threaded (I/O + on_http share thread)
  # Worker process count. 0 = non-forking mode.
  class << self
    attr_accessor :threads, :workers
  end

  # Starts server. Blocks until server stops.
  def self.start(); end

  # Signals stop. From master: MUST signal all workers to stop.
  def self.stop(); end

  # True if current process is root/master. Non-forking: always true.
  def self.master?(); end

  # True if current process is worker (even if also master). Non-forking: always true.
  def self.worker?(); end

  # True if server running and stop not called/signaled.
  def self.running?(); end
end
```


## NeoRack Extensions

Implemented extensions **MUST** publish their existence by adding an appropriate key-value pair to the `Server.extensions` Hash.

The key name **MUST** be the symbol stated in extension specification.

The value for the key-value pair **MUST** be an array indicating the extension's version using [semantic versioning](https://semver.org).

For example, if the extension name is "metal" and the extension is version `"0.1.0-alpha.1"`, the key `Server.extensions[:metal]` **MUST** be set to `[0, 1, 0, "alpha", 1]`.


## The `Server::Event` Class

The `Server::Event` constant **MUST** point to the class from which `event` instances are created. Overwriting this constant **SHOULD NOT** change server behavior (the server maps its internal class to this public constant).

The `event` instance provides: (1) HTTP request information, (2) an editable key-value store, and (3) a response API for streaming, sending, or upgrading connections.

The following class definition is the **normative specification**:

```ruby
class Event
  # MAY inherit from any class (e.g., Hash)

  #---------------------------------------------------------------------------
  # Request Attributes (read/write)
  #---------------------------------------------------------------------------

  # The NeoRack app/middleware handling this event
  attr_accessor :handler

  # HTTP method (e.g., "GET", "POST"). MUST NOT be empty string.
  attr_accessor :method

  # Request path without query (e.g., "/user" from "/user?id=0")
  # MUST NOT be empty string - empty MUST be replaced with "/"
  attr_accessor :path

  # Original path before routing consumed prefixes. Same rules as `path`.
  attr_accessor :opath

  # Query string after "?" (e.g., "id=0" from "/user?id=0")
  # MAY be nil or empty string when no query present
  attr_accessor :query

  # HTTP protocol version (e.g., "HTTP/1.1", "HTTP/2")
  attr_accessor :version

  # Request body length in bytes. Returns 0 if no body received.
  attr_accessor :length

  # Reserved for Rack compatibility extension (see extensions/rack.md)
  attr_accessor :env

  #---------------------------------------------------------------------------
  # Key-Value Store (headers + app data)
  #---------------------------------------------------------------------------
  # Key types and reservations:
  #   String keys  -> incoming HTTP headers (lowercase, server-populated)
  #   Symbol keys  -> app/middleware data
  #   :_*          -> reserved for server/extension internals
  #   :neorack_*   -> reserved for exposed server data
  #   :neorack_<ext>_* -> reserved for extension <ext>
  #
  # Multi-value headers: SHOULD be Array, MAY be comma-separated String
  # Servers MAY lazily parse headers (only when accessed)
  #---------------------------------------------------------------------------

  # @param key [String, Symbol] String for headers, Symbol for app data
  # @return value or nil if key not found
  # Servers MUST normalize header names to lowercase
  def [](key); end

  # @param key [String, Symbol] MUST be String or Symbol only
  # @param value - if nil, key MUST be removed from store
  def []=(key, value); end

  # Yields (key, value) pairs. Block MUST be provided (SHOULD raise if missing).
  # With lazy headers, MAY only yield previously-accessed headers.
  def each(&block); end

  # Forces server to parse ALL headers, returns self for chaining.
  # Use: e.headers.each { |k,v| ... } to iterate all headers
  def headers; self; end

  #---------------------------------------------------------------------------
  # Response: Status & Headers
  #---------------------------------------------------------------------------

  # HTTP status code. Default SHOULD be 200.
  # MUST be valid HTTP status. 0 is reserved for extensions (treat as 200).
  # Setting after headers sent SHOULD be ignored.
  # For 1xx/204/304: server MUST NOT send content-length/content-type/body
  attr_accessor :status

  # Sets response header. Returns true on success, false if headers locked.
  # @param name [String] MUST be lowercase. Servers MAY convert to lowercase.
  # @param value [String, Array<String>, nil]
  #   nil    -> SHOULD return false (MAY delete header, apps MUST NOT rely on this)
  #   String -> adds header; duplicate names SHOULD send multiple headers
  #   Array  -> behaves as multiple calls with same name
  # MUST be treated as irreversible - server MAY send immediately.
  # Returns false after write() or finish() called.
  def write_header(name, value); end

  # True if headers locked (already sent). MAY return false if trailers possible.
  def headers_sent?; end

  #---------------------------------------------------------------------------
  # Response: Body
  #---------------------------------------------------------------------------

  # Streams data to client. Returns true if accepted, false otherwise.
  # @param data [String, IO, nil, Object] MUST accept String and nil
  #   nil -> sends pending headers (locks further write_header calls)
  #   IO  -> server MUST call data.close (even if send fails)
  # First call locks headers. Multiple calls allowed (uses chunked encoding
  # or Connection:close for HTTP/1.1 if content-length not set).
  # SHOULD return false (not raise) on connection failure.
  def write(data); end

  # Completes response. Returns true first call, false on subsequent.
  # @param data [String, IO, nil] same semantics as write()
  # Subsequent calls ignored (but IO.close still called).
  # If no prior write(), server MAY set content-length before sending data.
  def finish(data = nil); end

  # True if connection open and finish() not yet called.
  def valid?; end

  #---------------------------------------------------------------------------
  # Request Body Reading
  #---------------------------------------------------------------------------

  # Returns next line (up to \n) or nil on EOF.
  # @param limit [Integer, nil] max bytes to read (stops at \n or limit)
  def gets(limit = nil); end

  # Reads body data. Returns ASCII-8BIT string or nil on EOF.
  # @param maxlen [Integer, nil] nil=read all, 0=empty string, n=up to n bytes
  # @param out_string [String, nil] buffer to receive data (returned instead)
  def read(maxlen = nil, out_string = nil); end

  # Gets/sets read position in body.
  # @param pos [Integer, nil]
  #   nil      -> returns current position
  #   >= 0     -> seeks to pos bytes from start
  #   negative -> seeks to (end + pos), where -1 = EOF
  # Clamps to [0, body_length]. Returns new position.
  def seek(pos = nil); end

  #---------------------------------------------------------------------------
  # Connection Info
  #---------------------------------------------------------------------------

  # Peer IP address without port (e.g., "192.168.1.1", "::1")
  # SHOULD be parseable by IPAddr.new. MUST return nil if unknown.
  # Servers MAY always return nil.
  def peer_addr; end

  # (Optional) SHOULD raise - event MUST NOT be duplicated by apps
  # def dup; raise "Event cannot be duplicated"; end
end
```


## Middleware

The following is the **normative specification**:

```ruby
# Middleware MUST delegate unhandled methods to the wrapped app.
# Middleware MAY call e.finish early to stop request propagation.
# Middleware SHOULD NOT replace the event object (unpredictable results).
# WARNING: Replacing e.handler breaks middleware cleanup (different stack).
class Middleware
  def initialize(app)
    @app = app
  end

  def on_http(event)
    @app.on_http(event)
  end

  def on_finish(event)
    @app.on_finish(event)
  end

  private

  # MUST delegate unknown methods to wrapped app
  def method_missing(method_name, *arguments, &block)
    @app.send(method_name, *arguments, &block)
  end

  def respond_to_missing?(method_name, include_private = false)
    @app.respond_to?(method_name, include_private) || super
  end
end
```

## Error Handling

| Scenario | Requirement |
|----------|-------------|
| **Exception in on_http** | |
| Response not sent | Server SHOULD respond with HTTP 500 |
| Cleanup | Server MUST call on_finish (if defined) |
| Logging | Server SHOULD log the exception |
| **Write failure (e.g., disconnect)** | |
| write/finish return | SHOULD return `false` (not raise) |
| valid? | MUST return `false` after failure detected |
| Cleanup | Server MUST call on_finish (if defined) |

## Security Considerations

| Area | Requirement |
|------|-------------|
| **Header validation** | Servers SHOULD validate names (HTTP tokens) and values (HTTP field content); SHOULD reject malformed |
| **Path security** | Servers MUST normalize paths (prevent `/../` traversal); `path`/`opath` MUST NOT contain unresolved `..` |
| **Body limits** | Servers SHOULD support configurable max size; SHOULD reject with HTTP 413 |
| **TLS** | Production SHOULD use TLS; servers SHOULD support TLS 1.2+ |

## NeoRack DSL

Servers implementing a CLI SHOULD expect `config.nru` as default and implement this DSL:

```ruby
module Server::DSL
  # Adds middleware to the application stack.
  # @param middleware [Class] middleware class
  # @param args - passed to middleware.new(app, *args, &block)
  def use(middleware, *args, &block) ; end

  # Maps URL path prefix to a NeoRack application.
  # @param path [String, nil] prefix to match (nil = root '/')
  #   MUST only match prefixes: 'user' matches /user, /user/, /user/...
  #   MUST normalize: '/user/', 'user', '/user', 'user/' behave identically
  #   MUST be case sensitive
  #   MUST NOT provide sophisticated routing (e.g., '/user/(:id)')
  # @param handler [Object, nil] NeoRack application
  # @param block - if given, use/run MAY be called within (scoped middleware)
  # Calls MAY be nested.
  # Routing MUST update e.path, removing consumed prefixes.
  # If handler nil and no block: SHOULD return handler for that path.
  def map(path = nil, handler = nil, &block) ; end

  # Sets the NeoRack application to run.
  # @param handler [Object, nil] NeoRack application
  # @param block - with Rack extension: MAY act as handler. Otherwise: SHOULD raise.
  def run(handler = nil, &block) ; end
end
```

### Example `config.nru`

```ruby
# A default response for the sample NeoRack application
DEFAULT_RESPONSE = "Hello, World!".freeze

# A NeoRack application, including all possible core callbacks.
module ExampleApp
  def self.on_http(e)
    e.finish(DEFAULT_RESPONSE)
  end

  def self.on_finish(e)
    puts "#{Process.pid}: finished processing the HTTP request."
  end
end

module NestedApp
  def self.on_http(e)
    e.finish("NeoRack took us here, with path: #{e.path}")
  end
end
map('secret', NestedApp)
run ExampleApp
```

