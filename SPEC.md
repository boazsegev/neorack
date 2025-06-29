# NeoRack - A New Server-Application Bridge Protocol

**Protocol Specification Version:** `0.0.2` (`[0, 0, 2]`)

This specification lists the requirements for NeoRack-compatible **Servers**, **Applications**, and **Middleware**.

## NeoRack Applications

```ruby
# A NeoRack application, including all possible core callbacks.
module EXAMPLE_APP
  # Called for every HTTP request
  def self.on_http(e) ; end

  # Called after `on_http` (or after `on_closed` if WebSocket/SSE extensions are supported)
  def self.on_finish(e) ; end
end

```

A NeoRack application is a Ruby object, singleton class, or module.

A NeoRack application **MUST** respond to the `on_http` method. The `on_http` method **MUST** take exactly one argument, `event` (herein: `e`), as defined in this specification.

A NeoRack application **MUST** call `e.finish` for every event (`e`) forwarded to its `on_http` method. A NeoRack application **MAY** call `e.finish` even after `on_http` has returned.

- `#on_http(e)` - **(required)**: Called for every HTTP request with a new (unique) `e` instance.

- `#on_finish(e)` - **(optional)**: If provided, NeoRack servers **MUST** call this method for cleanup before the `e` object is garbage collected (i.e., before the server releases all references to `e`). For HTTP connections, this would typically be immediately after the response is sent.

**Note:** NeoRack applications **SHOULD** be thread-safe and assume that the `on_http` method might be called concurrently from different threads or processes. To improve thread safety, NeoRack applications **SHOULD NOT** use global mutable variables or application instance variables and **SHOULD** limit any mutable state storage to the key-value store in the event object (`e`) and/or a separate, thread-safe module.

## NeoRack Servers

NeoRack servers **MUST** support this specification and **MAY** support any extensions they see fit.

NeoRack servers **MUST** support at least one NeoRack application per server instance and **MAY** support multiple applications concurrently (e.g., by listening to multiple sockets or implementing a routing layer).

## The `Server` Object

```ruby
module Server
  def extensions; @extensions ||= { neo_rack: [0, 0, 2] } ; end

  def self.listen(url, handler); end

  def self.on_state(state, &block); end

  attr_accessor :threads, :workers

  def self.start(); end
  def self.stop(); end

  def self.master?(); end
  def self.worker?(); end
  def self.running?(); end
end
```

NeoRack servers **MUST** map the `Server` constant to the module or class implementing the required NeoRack API. If the `Server` constant is already defined (e.g., due to another NeoRack server being loaded), the server **MAY** choose to overwrite the constant.

The `Server` object provides:

1. Information about the server.
2. Access to the server's API.
3. A link between NeoRack applications and the NeoRack server.

A `Server` object **MUST** respond to the following methods:

- `extensions`: Returns a hash of supported extensions (key-value pairs).

  - The key **MUST** be a symbol containing the extension name.

  - The value **MUST** be an array indicating the extension's version ([semantic versioning](https://semver.org)).

  - The `Server` object **MUST** include the `:neo_rack` key in the `extensions`, indicating the version of the NeoRack specification it supports.

- `listen(url, handler)`: Configures the server to listen on the given `url` and use the specified `handler` to process incoming requests.

  - `url` **MUST** be a string in URL format (e.g., `"https://localhost:3000"` or `"unix://./my_unix.sock"`). If `url` is `nil`, the server **SHOULD** choose a reasonable default behavior.

    Servers **MAY** process the `url` as they see fit, possibly ignoring the `path` part of the URL.

    For example, some servers may provide routing support, while others may ignore the path or offer TLS support by parsing the scheme or query data in the `url`.

  - `handler` **MUST** be a valid NeoRack application.

  - Servers **MAY** support multiple `listen` calls, allowing them to listen on multiple addresses or URLs.

- `start`: Starts the server (blocks until the server stops).

- `stop`: Signals the current server worker to stop. If called from the master/root process, it **MUST** signal all worker processes to stop.

- `threads`: Returns the number of threads the server uses for calling `on_http` concurrently (or `0` if the server only uses a single thread for both `on_http` and I/O).

- `workers`: Returns the number of worker processes the server spawns (or `0` if the server runs in a non-forking mode).

- `master?`: Returns `true` if the current process is the root/master process. If the server is non-forking, this method always returns `true`.

- `worker?`: Returns `true` if the current process is a worker process (even if it's also the master process). If the server is non-forking, this method always returns `true`.

- `running?`: Returns `true` if the server is running, `stop` hasn't been called, and a stop signal hasn't been detected.

- `on_state(state, &block)`: Registers a callback to be called when the server enters the given state.

  - `state` **MUST** be a symbol, and the following states **MUST** be supported:

    - `:start`: The worker process is starting. If non-forking, the master process is considered a worker and enters this state after `Server.start` is called.

    - `:start_shutdown`: The current process is shutting down its server.

    - `:stop`: The server in the current process stopped.

    - The server **MAY** support additional states.

  - `block` **MUST** be a Proc object used as a callback and **MUST NOT** take any arguments.

  - Servers **MUST** support multiple `on_state` calls, allowing multiple callbacks for a given state.


## NeoRack Extensions

Implemented extensions **MUST** publish their existence by adding an appropriate key-value pair to the `Server.extensions` Hash.

The key name **MUST** be the symbol stated in extension specification.

The value for the key-value pair **MUST** be an array indicating the extension's version using [semantic versioning](https://semver.org).

For example, if the extension name is "metal" and the extension is version `"0.1.0-alpha.1"`, the key `Server.extensions[:metal]` **MUST** be set to `[0, 1, 0, "alpha", 1]`.


## The `Server::Event` Class

The `Server::Event` constant **MUST** point to the class from which `event` instances are created.

NeoRack servers **MUST** map the `Server::Event` constant to the class implementing the NeoRack events.

**Note:** Overwriting the `Server::Event` constant with another constant **SHOULD NOT** change the server's behavior. This is because the server only maps its own internal class to the public constant, making it possible to add functionality to its internal class (not overwriting it).

```ruby
class Event
  attr_accessor :handler

  attr_accessor :method
  attr_accessor :path
  attr_accessor :opath
  attr_accessor :query
  attr_accessor :version

  attr_accessor :env

  def headers; self; end
  def [](key); end
  def []=(key, value); end
  def each(&block); end

  def headers_sent?; end
  def valid?; end

  attr_accessor :status
  def write_headers(name, values); end
  def write(data); end
  def finish(data = nil); end

  # HTTP Body / Payload

  attr_accessor :length
  def gets(limit = nil); end
  def read(maxlen = nil, out_string = nil); end
  def seek(pos = nil); end

end
```

## The `event` Instance Object (herein `e`)

The `event` instance object is designed to provide:

1. Information about the HTTP request.
2. An editable data store for each HTTP request.
3. An API allowing a response to be either streamed, sent, or upgraded (if supported).

An `event` instance object **MAY** inherit from any class (e.g., `Hash` may be appropriate) and **MUST** implement the instance methods listed here:


- `[](key)`: Returns the value associated with the given `key`. If no such value exists, it **MUST** return `nil`.

  - NeoRack servers **MUST** make incoming HTTP headers available as key-value pairs, where `key`s are **lowercase strings**.

    **Note:**

    Headers with multiple values **SHOULD** be an array of values but **MAY** be a comma-separated string (where allowed by the header type), or a combination of both (e.g., an array where some strings include multiple, comma-separated values).

    Abstracting these HTTP protocol details is considered a framework concern. It is recommended that applications aren't exposed to this HTTP detail, as it's potentially confusing.

  - NeoRack servers **MAY** lazily load header data, making header data available only if and when requested.

  - Middleware/Application data **SHOULD** use unreserved **symbol** `key`s unless overwriting header data.

  - **Symbol** `key`s starting with an underscore (`_`) are reserved for internal server and extension data.

  - **Symbol** `key`s starting with `neorack_` are reserved for exposed server data.

  - **Symbol** `key`s starting with `neorack_<extension_name>` are reserved for extensions, where `<extension_name>` is a placeholder for the actual extension name.

  - **String** `key`s are reserved for incoming header data.

- `[]=(key, value)`: Sets the value of the given `key`.

  - NeoRack applications **MUST** limit `key`s passed to the `[]` and `[]=` methods to one of the following native Ruby types: **String**, **Symbol**.

  - NeoRack servers **MAY** assume that `key`s are limited to the aforementioned allowed types and **MAY** throw an exception when an unallowed type is detected.

  - If `value` is `nil`, the `key` **MAY** be removed from the `event` object.

- `each(&block)`: Similar to `on_state`, this method accepts either a handler responding to `call` or a `block` (one of which **MUST** be provided). The `each` method will call `block.call(key, value)` or `yield(key, value)` for each key-value pair stored in the event storage.

  **Note:** An exception **SHOULD** be raised if `block` is missing, as there is no requirement to implement an Enumerator for the `each` method.

  **Note:** NeoRack servers **MAY** lazily load header data, in which case `each` **MAY** ignore headers that weren't previously accessed.

- `headers`: Used to overcome lazy header parsing when an app wants to iterate over all incoming headers. Returns `self`.

  **Note:** This method **MUST** return the `event` object itself, allowing for method chaining. Use of this method **MUST** force the server to parse all incoming headers and set them as accessible key-value pairs.

  For example:

  ```ruby
  # Prints all incoming headers, assuming NeoRack guidelines were followed:
  e.headers.each do |key, value|
    next unless key.is_a?(String) # ignore app / server data 
    if value.is_a?(Array)
      value.each { |v| puts "#{key}: #{v}" }
    else
      puts "#{key}: #{value}"
    end
  end
  ```

- The following attribute accessors (as if declared using `attr_accessor`): `path`, `opath`, `query`, `method`, and `status` — all initially set to `nil` unless otherwise specified or previously set.

  - `path`: Returns a string containing the request's path (e.g., `/user?id=0` results in `/user`). This **MUST NOT** be an empty string. An empty string **MUST** be replaced with `"/"`.

  - `opath`: Returns a string containing the request's original path (see `path`). This allows request routing to update the `path` property to remove any path prefixes (replacing an empty string with `"/"`).

  - `query`: Returns a string containing the request's query (the portion of the request URL that follows the `?`, if any; e.g., `/user?id=0` results in `id=0`). This **MAY** return either `nil` or an empty string when no query is present.

  - `method`: Returns a string containing the HTTP method used, e.g., `"GET"` or `"POST"`. This **MUST NOT** be an empty string.

  - `length`: Returns the total number of bytes in the HTTP request body (payload); returns `0` if no request body/payload was received.

- `gets`: Does **NOT** accept any arguments and returns a string containing the next "line," or `nil` on EOF.

- `read(maxlen = nil, out_string = nil)`: Behaves like a subset of `IO#read`.

  - `read` always reads data in binary format, returning a string in `ASCII-8BIT` encoding or `nil` on EOF.

  - If `read` is called without any arguments or with both `maxlen` and `out_string` set to `nil` (or missing), it returns a string containing all the remaining data in the body, or `nil` on EOF.

  - If `maxlen` is provided (and is not `nil`), it must be a positive number or zero. If `maxlen` is zero, an empty string is returned. Otherwise, `read` returns a string containing as much as possible of the remaining data in the body, **but no more than `maxlen` bytes** (or `nil` on EOF).

  - If the optional `out_string` argument is provided (and isn't `nil`), it must reference a string, which will receive the data—in which case either the `out_string` string is returned, or `nil` on EOF.

- `seek(pos)`: Behaves like a subset of `IO#seek`.

  - If `pos` is `nil`, `seek` must return the current byte position in the body.

  - If `pos` is a positive number or `0`, it moves the current read position in the body to `pos` bytes. If `pos` is negative, it moves the read position in the body to `EOF - pos` bytes (counts from the end), where `-1` is EOF.

  - If the current position in the body is moved beyond the end of the body, the current position is set to the end of the body.

  - If the current position in the body is moved before the start of the body, the current position is set to the start of the body.

  - The `seek` method **MUST** return the new current position in the body.


- `status`: Gets or sets the response status as a number. When setting the `status` (using `status = n`):

  - The new `status` **MUST** be a [valid HTTP status code number](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status).

  - Servers **SHOULD** set `status` to `200` as the default value indicating everything is okay.

  - Servers **MAY** treat invalid (non-zero) numbers as they see fit.

  - The number `0` is reserved for extensions and **MUST** either be treated as described in any implemented extension or as `200 OK`.

  - Servers **SHOULD** ignore a `status=` call if the response status was already sent.

  - **Note:** Servers **MUST NOT** send the `"content-length"` or `"content-type"` headers (nor any payload) when the `status` is 1xx, 204, or 304. In these cases, any calls to `write` or any `data` argument passed to `finish` **MUST** be ignored by the server (except that `data.close` **MUST** still be called if `data` is a `File` instance).

- **`write_header(name, value)`**: Sets a response header and returns `true`. If headers have already been sent, or if either `write` or `finish` has been previously called, it **MUST** return `false`.

  - The header `name` **MUST** be a lowercase `String`. Servers **MAY** enforce this by converting string objects to lowercase.

  - Servers **MAY** accept a `Symbol` as the header `name`. Applications **MUST NOT** rely on such behavior.

  - The `value` **MUST** be either a `String`, an `Array` of Strings, or `nil`. Servers **SHOULD NOT** (but **MAY**) accept other `value` types (e.g., `Symbol`).

    - **If `value` is `nil`**:
      - The server **SHOULD** do nothing and return `false`.
      - Alternatively, the server **MAY** delete any existing headers named `name` from the response (as if `write_header` had never been called for that header) and return `true`. Applications **MUST NOT** rely on such behavior.

    - **If `value` is a `String`**:
      - A response header with the given `name` is added to the response and set to `value`. If `name` already exists, servers **SHOULD** send multiple headers with the same `name`, but **MAY** append `value` to the existing header using HTTP semantics.
      - Servers **MAY** split `value` on newline characters and treat it as an array of `String`s (for backward compatibility with old-style Rack). Applications **MUST NOT** rely on such behavior.

    - **If `value` is an `Array` of `String`s**:
      - The method behaves as if called multiple times with the same `name`, once for each element of `value`.

  - The `write_header` method **MUST** be considered by any NeoRack application as **irreversible**. Servers **MAY** write the header immediately to the client.

- `write(data)`: **Streams** the data, using the appropriate encoding. **Note:**

  - NeoRack servers **MAY** accept any Ruby object as `data`, and **MUST** accept either a String instance or `nil`.

  - If `data` is `nil`, servers MUST send any pending headers, making further calls to `write_header` behave accordingly.

  - If `data` is an `IO` instance, then the server **MUST** call `data`'s `close` method at the appropriate time. This **MUST** be done whether `data` can be sent or not and whether the server chooses to support `File` / `IO` objects as acceptable `data`.

  - The server **MUST** allow `write` to be called multiple times while following the HTTP protocol specifications.

    For example, when running HTTP/1.1 and the `"content-length"` header hadn't been set prior to a call to `write`, the server **MUST EITHER** use `chunked` [transfer encoding](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding), **OR** set the [`Connection: close` header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Connection) and close the connection once `finish` is called.

  - If the headers weren't previously sent, they **MUST** be sent (or locked) at this point. Once `write` or `finish` are called, calls to `write_header` **MUST** return `false`.

  - `write` **MUST** return `true` if the server accepted the `data` object to be sent. If `data` will NOT be sent, the server **SHOULD** return `false` rather than raising an exception.


- `finish(data = nil)`: Completes the response. Note:

  - Subsequent calls to `finish` **MUST** be ignored (except `close` **MUST** still be called if `data` is a `File` instance).

  - `data` **MUST** follow the same semantics as in `write`, but it **MAY** be `nil` (no additional data to send).

  - If the headers weren't previously sent, they **MUST** be sent before sending any data.

  - If `data` was provided, it should be sent. If no previous calls to `write` were made, the server **MAY** set the `"content-length"` for the response before sending the `data`.

- `headers_sent?`: Returns `true` if additional headers cannot be sent (the headers were already sent). Otherwise, returns `false`. Servers **MAY** return `false` **even if** some headers were sent, as long as it is possible to send additional headers - e.g., if the response is implemented using `chunked` encoding with trailers, allowing certain headers to be sent after the response was sent.

- `valid?`: Returns `true` if data may still be sent (the connection is open and `finish` hasn't been called yet). Otherwise, returns `false`.

- `peer_addr`: **SHOULD** return the peer's network address as a string. If the address is unknown, this method **MUST** return `nil`. Servers **MAY** always return `nil`.

- `dup`: (optional) **SHOULD** raise an exception, as the `event` object **MUST NOT** be duplicated by the NeoRack application.


## MiddleWare

Applications somehow replacing the `e.handler` object **MUST** be aware that the middleware might not be able to perform cleanup, as the middleware stack for the new handler might be different from the existing middleware stack.

NeoRack middleware is a singleton module or class. It **MUST** delegate any unhandled method calls to the NeoRack application and behave as if it were the application itself.

For example:

```ruby
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

  def method_missing(method_name, *arguments, &block)
    @app.send(method_name, *arguments, &block)
  end
end
```

Middleware **MAY** stop the request from reaching the application by calling either `e.finish` or `e.close` before the next middleware or the application is called.

Middleware **SHOULD NOT** replace the `event` object with a new `event` object. Although this would allow the middleware to control the application's behavior, it might cause unpredictable results.

## NeoRack DSL

When implementing a CLI for the NeoRack Server, it is expected (but not required) that servers expect the default application file named `config.nru` and implement the following DSL for that file:

```ruby
module DLS
  def use(middleware, *args, &block) ; end
  def map(path = nil, handler = nil, &block) ; end
  def run(handler = nil, &block) ; end
end
```
### DSL Methods

#### `use`

Adds Middleware to the application stack.

#### `run`

Sets NeoRack application for the server to run.

When supporting classical Rack, `block` may act as an handler. Otherwise, `block` **SHOULD** raise an exception.

#### `map`

Maps a URL path to a specific NeoRack Application.

Accepts an optional block to run within the scope of the path (where `use` and `run` **MAY** be called).

Calls to `map`  **MAY** be nested.

Request routing **SHOULD** update the event's `path` property, removing any consumed path prefixes.

If `handler` is `nil` and no `block` is provided, `map` should return the handler that would have been used if `path` was passed to the router.

**Note**:

- `map`, when implemented, **SHOULD** only test for path prefixes. i.e, the path `'user'` should match: `/user`, `/user/`, `/user/...`. This **SHOULD NOT** attempt to provide a sophisticated routing solution (i.e., `'/user/(:id)'`).

- `map` **SHOULD** behave the same when faced with paths with or without the `'/'` prefix / postfix. i.e., the following should behave the same: `'/user/'`, `'user'`, `'/user'` or `'user/'`.

- If `path` is `nil`, it should be treated the same as the root path `'/'` (the default / fallback handler would be set / returned).

- `map` **SHOULD** be case sensitive.

- When `use` is called inside a `map` block, it should only affect the middleware chain related to that specific path.

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

