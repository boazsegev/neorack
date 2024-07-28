# NeoRack - a new Server-Application Bridge Protocol

Protocol Specification version: 0.0.2 (`[0, 0, 2]`).

The following specification lists the requirements for a New-Rack compatible **Servers**, **Applications** and **MiddleWare**.

## NeoRack Applications

A NeoRack application is a Ruby Object, singleton Class or Module.

A NeoRack application **MUST** responds to the `on_http` method. The `on_http` method **MUST** take exactly one argument, which is the `event` argument (herein: `e`), as defined in this specification.

A NeoRack application **MUST** call `e.finish` for every event (`e`) forwarded to it's method `on_http`. A NeoRack application **MAY** call `e.finish` even after `on_http` had returned.

* `#on_http(e)` - (required) called for every HTTP request with a new (different) `e` instance object.

* `#on_finish(e)` - (optional) called for every HTTP request with after the response had finished and before the `e` object is allowed to be Garbage Collected (before the Server releases all references to `e`).

**Note**: ideally NeoRack application **SHOULD** be thread safe and assume that the method `on_http` might be called concurrently from different threads or processes. Applications **SHOULD NOT** use mutable instance variables and **SHOULD** limit any mutable state storage to the event (`e`) object and/or a separate, thread safe, module.

### Example NeoRack Application

```ruby
# The default response for the sample NeoRack application
DEFAULT_RESPONSE = "Hello, World!".freeze

# A NeoRack application, including all possible Application callbacks.
module EXAMPLE_APP
    # Called for every HTTP request
    def self.on_http(e)
        e.finish(DEFAULT_RESPONSE)
    end
    # Called for every HTTP request after it had been completed
    def self.on_finish(e)
        puts "#{Process.pid}: I don't handle any more HTTP requests."
    end
end

Server.listen nil, EXAMPLE_APP
```

### Example `config.nru`

Similarly to the classical Rack approach, NeoRack Servers **SHOULD** support `.ru` and `.nru` Web Application Configuration Files.

Such files use a similar DLS approach as employed by Rack, aiming for compatibility where possible.

NeoRack DSL is limited to the `use` and `run` methods, where `use` is used to add MiddleWare and `run` is used to set the application and start the Server.

This would allow Servers to support both NeoRack and Rack applications simultaneously.

```ruby
# The default response for the sample NeoRack application
DEFAULT_RESPONSE = "Hello, World!".freeze

# A NeoRack application, including all possible Application callbacks.
module EXAMPLE_APP
    # Called for every HTTP request
    def self.on_http(e)
        e.finish(DEFAULT_RESPONSE)
    end
    # Called for every HTTP request after it had been completed
    def self.on_finish(e)
        puts "#{Process.pid}: I don't handle any more HTTP requests."
    end
end

run EXAMPLE_APP
```

## NeoRack Servers

NeoRack servers **MUST** support this specification and **MAY** support any extensions they see fit.

NewRack servers **MUST** support at least one NeoRack application and **MAY** support multiple applications at a time (i.e., when listening to multiple sockets or when implementing a routing layer).

## The `Server` Object

NeoRack Servers **MUST** map the `Server` constant to the module / class in which they implement the required NeoRack API. If the `Server` constant was already defined (i.e., if another NeoRack server loaded), the Server MAY choose to overwrite the constant.

The `Server` object is designed to provide:

1. Information about the server.
1. Access to the Server API.
1. A link between NeoRack applications and the NeoRack Server.

A `Server` object **MUST** respond to the following methods:

* `extensions` - Returns a Hash map of supported extensions (as key-value pairs).

    * The key **MUST** be a Symbol containing the extension name.

    * The value **MUST** be an Array indicating the extensions version using [semantic versioning](https://semver.org).

    * The `Server` object **MUST** include the `:neo_rack` key, indicating the version of the NeoRack specification it supports.

* `listen(url, handler)` - Sets the servers to listen on the given `url` and use the given `handler` to process incoming requests.

    * `url` **MUST** be a String containing and address to listen on in URL format (i.e., `"https://localhost:3000"` or `"unix://./my_unix.sock"`). A NeoRack Server **MAY** allow `url` to be `nil`, in which case the Server **SHOULD** decide on the address to listen at.

        Servers **MAY** process the `url` in any way they desire and **MAY** ignore the `path` part of the `URL`. i.e., Some Servers may provide routing support, while others may ignore the `path` part of the URL.

    * `handler` **MUST** be a valid NeoRack application.

    * Servers **MAY** support multiple `listen` calls, allowing them to listen on multiple addresses or URLs.

* `start` - Starts the Server (blocks until the Server stops).

* `stop` - Signals the current Server `worker` to stop. If called from the `root` / `master` process, it **MUST** signal all `worker` processes to stop as well.

* `threads` - **MUST** return the number of threads that the server will use for calling `on_http` concurrently (or `0` if the Server only uses a single thread for both the `on_http` callback and the IO).

* `workers` - **MUST** return the number of "worker" processes that the server will spawn (or `0` if the server will run in a non-forking mode).

* `master?` - Returns `true` only if the current process is the `root` / `master` process. If the server is non-forking, this method should always return `true`.

* `worker?` - Returns `true` only if the current process is a `worker` process (even if it is also the `root` / `master` process). If the server is non-forking, this method should always return `true`.

* `running?` - Returns `true` only if the Server is running, `stop` wasn't called **and** a stop signal hadn't been detected.

* `on_state(state, &block)` - Request the server to call the given `block` when the server enters the given `state`.

    * `state` **MUST** be a Symbol. At the very least, the following states **MUST** be supported:

        * `:on_start` - a `worker` process is starting. If the Server is non-forking, the `root` / `master` process is considered a `worker` and enters this state after `Server.start` has been called.

        * `:start_shutdown` - The current process is shutting down the Server.

        * `:on_finish` - The current process finished shutting down the Server.

        * The Server **MAY** support additional states.

    * `block` **MUST** be a Proc object used as a callback. The Proc object **MUST NOT** take any arguments.

    * Servers **MUST** support multiple `on_state` calls, allowing them to call multiple `block`s when the server enters the given `state`.

## The `Server::Event` Class

The `Server::Event` constant MUST point to the class from which `Server` events are instantiated.

NeoRack Servers **MUST** map the `Server::Event` constant to the class implementing the NeoRack events.

**Note**: overwriting the `Server::Event` constant with another constant SHOULD NOT change the Server's behavior. This is because the Server **MUST** use the `Server::Event` constant to instantiate `events`.


## The `event` Instance Object (herein `e`)

The `event` instance object is designed to provide:

1. Information about the HTTP request.
1. An editable data store for each HTTP request.
1. An API allowing a response to be either streamed, sent or upgraded (if supported).

An `event` instance object **MAY** inherit from any class (Hash may be most appropriate) and **MUST** implement the instance methods listed here:

* `[key]` - returns the value associated with the given `key`. If no such value exists, it **MUST** return `nil`. Note:

    * NeoRack Servers **MUST** make incoming HTTP headers available as key-value pairs, where `key`s are **Lowercase Strings**.

        **Note**:

        Headers with multiple values **SHOULD** be an Array of values, but **MAY** be a comma separated String (where allowed by the Header type), or a combination of both (i.e., an Array where some Strings include multiple, comma separated, values).

        Abstracting these HTTP protocol details is considered a Framework concern. It is recommended that applications aren't exposed to this HTTP detail, as it's potentially confusing.

    * NeoRack Servers **MAY** lazily load header data, making header data available only if and when requested.

    * MiddleWare / Application Data **SHOULD** use unreserved **Symbol** `key`s unless overwriting header data.

    * **Symbol** `key`s starting with an underscore (`_`) are reserved for internal Server and Extension data.

    * **Symbol** `key`s starting with `neorack_` are reserved for exposed Server Data.

    * **Symbol** `key`s starting with `neorack_<extension_name>` are reserved for Extensions, where `<extension_name>` is a place holder for the actual extension name.

    * **String** `key`s are reserved for incoming Header data.

* `[key]=value` - sets the value of the given `key`.

    * NeoRack Applications **MUST** limit `key`s passed to the `[]` and `[]=` methods to one of the following native Ruby Types: **String, Symbol**.

    * NeoRack Servers **MAY** assume that `key`s are limited to one of the aforementioned allowed types and **MAY** throw an exception when an allowed type is detected.

    * if `value` is `nil`, the `key` **MAY** be removed from the `event` object.

* `each(&block)` - similarly to `on_state`, this method accepts either a handler answering `call` or a `block` (one of which **MUST** be provided). The `each` method will call `block.call(key, value)` or `yield(key, value)` for each key-value pair stored in the event storage.

    **Note**: an Exception **SHOULD** be raised if `block` is missing, as there is no requirement to implement an Enumerator for the `each` method.

    **Note**: NeoRack Servers **MAY**  lazily load header data, in which case `each` **MAY** ignore headers that weren't previously accessed.

* `headers` – used to overcome lazy header parsing when an app wants to iterate over all incoming headers. Returns `self`.

    **Note**: This method **MUST** return the `event` object itself, allowing for method chaining. Use of this method **MUST** force the Server to parse all incoming headers and set them as accessible key-value pairs.

    For example:

    ```ruby
    # Prints all incoming headers, assuming NeoRack guidelines were followed:
    e.headers.each do |key, value|
        if(value.is_a? Array)
            value.each {|v| puts "#{key}: #{v}" }
        else
            puts "#{key}: #{value}"
        end
    end
    ```

* The following attributes (as if declared using `attr_accessor`): `path`, `query`, `method`, `scheme`, and `status` - all initially set to `nil` unless otherwise specified or previously set.

* `path` - returns a String containing the requests path (i.e., `/user?id=0` will result in `/user`). This **MAY NOT** be an empty String. An empty String **MUST** be replaced with the String `"/"`.

* `query` - returns a String containing the requests query (the portion of the request URL that follows the `?`, if any, i.e., `/user?id=0` will result in `id=0`). This **MAY** return either `nil` or an empty String when no query was made.

* `method` -  returns a String containing the HTTP method used, i.e., `"GET"` or `"POST"`. This **MUST NOT** be an empty String.

* `scheme` -  returns a String containing the HTTP scheme (`http` / `https`) is available. This value **MUST** be `nil` if the scheme is unknown.

* `length` - returns the total number of bytes in the HTTP request body (payload), returns 0 if no request body / payload was received.

* `gets` does **NOT** accept any arguments and returns a String containing the next "line", or `nil` on EOF.

* `read` behaves like a subset of `IO#read`. Its signature is `read(maxlen = nil, out_string = nil)`.

    * `read` always reads data in binary format, returning a String in `ASCII-8BIT` encoding or `nil` on EOF.

    * If `read` is called without any arguments or with both `length` and `outbuf` set to `nil` (or missing), it returns a String containing all the remaining data in the `body`, or `nil` on EOF.

    * If `length` is provided (and is not `nil`), `length` must be a positive number or zero. If `length` is zero, an empty String is returned. Otherwise, `read` returns a String containing as much as possible of the remaining data in the `body`, **but no more than `length` bytes** (or `nil` on EOF).

    * If the optional `outbuf` argument is provided (and isn't `nil`), it must reference a String, which will receive the data - in which case either the `outbuf` String is returned, or `nil` on EOF.

* `seek` - behaves like a subset of `IO#seek`. Its signature is `seek(pos)`.

    * If `pos` is a positive number, it moves the current read position in the `body` to `pos` bytes. If `pos` is negative, it moves the read position in the `body` to `EOF-pos` bytes (counts from the end), where `-1 == EOF`.

    * If the current position in the `body` is moved beyond the end of the `body`, the current position is set to the end of the `body`.

    * If the current position in the `body` is moved before the start of the `body`, the current position is set to the start of the `body`.

    * The `seek` method **MUST** return the new current position in the `body`.

* `status`- gets / sets the response status as a Number. When setting the `status` (using `status=n`):

    * New `status` **MUST** be a [valid HTTP status code Number](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status).

    * Servers sould set `status` to `200` as the default value indicating everything is okay.

    * Servers **MAY** treat invalid (non-zero) numbers as they see fit.

    * The number `0` is reserved for extensions and **MUST** either be treated as described in any implemented extension or as `200 OK`.

    * Servers **SHOULD** ignore a `status=` call if the response status was already sent.

    * Note: Servers **MUST NOT** send the `"content-length"` or `"content-type"` headers (nor any payload) when the `status` is 1xx, 204 or 304. In these cases, any calls to `write` or any `data` argument passed to `finish` **MUST** be ignored by the server (except `data.close` **MUST** still be called if `data` is a `File` instance).

* `write_header(name, value)` - sets a response header and returns `true`. If headers were already sent or either `write` or `finish` previously called, it **MUST** return `false`.

    * The header `name` **MUST** be a lower case String. Servers **MAY** enforce this by converting String objects to lower case.

    * The `write_header` method is **irreversible**. Servers **MAY** write the header immediately, as they see fit.

    * When frameworks provide an interface for setting cookies, they **SHOULD** consider supporting all the features available for the [`set-cookie` header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie).

* `write(data)` - **streams** the data, using the appropriate encoding. **Note**:

    * NeoRack Servers MAY accept any Ruby Object as `data`, and MUST accept a String instance.

    * If the Server accepts an `IO` instances as `data`, then the server **MUST** call `data`'s `close` method at the appropriate time. This **MUST** be done whether `data` ca be sent or not.

    * The Server MUST allow `write` to be called multiple times while following the HTTP protocol specifications.

        For example, when running HTTP/1.1 and the `"content-length"` header hadn't been set prior to a call to `write`, the server **MUST EITHER** use `chunked` [transfer encoding](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding), **OR** set the [`connection: close` header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Connection) and close the connection once `finish` was called.

    * If the headers weren't previously sent, they **MUST** be sent (or locked) at this point. Once `write` or `finish` are called, calls to `write_header` **MUST** return `false`.

    * `write` MUST return `true` if the Server accepted the `data` Object to be sent. If `data` will NOT be sent, the Server SHOULD return `false` rather than raising an exception.

* `finish([data])` - completes the response. Note:

    * Subsequent calls to `finish` **MUST** be ignored (except `close` **MUST** still be called if `data` is a `File` instance).

    * `data` MUST follow the same semantics as in `write`, but it MAY be `nil` (no additional data to send).

    * If `data` is an `IO` instance, then the server **MUST** call it's `close` method.

    * If the headers weren't previously sent, they **MUST** be sent before sending any data.

    * If `data` was provided, it should be sent. If no previous calls to `write` were made, the server **MAY** set the `"content-length"` for the response before sending the `data`.

* `headers_sent?` - returns `true` if additional headers cannot be sent (the headers were already sent). Otherwise returns `false`. Servers **MAY** return `false` **even if** the response is implemented using `chunked` encoding with trailers, allowing certain headers to be sent after the response was sent.

* `valid?` - returns `true` if data may still be sent (the connection is open and `finish` hadn't been called yet). Otherwise returns `false`.

* `peer_addr` - **MUST** return the peers address as a String. If the address is unknown, it **MUST** return `nil`. Servers **MAY** always return `nil`.

* `dup` - (optional) **SHOULD** throw an exception, as the `event` object **MUST NOT** be duplicated by the NeoRack Application.
 
## NeoRack Extensions

Servers implementing a NeoRack extension **MUST** indicate their support by adding an appropriate key-value pair to the `event` instance object.

The key name **MUST** be a Symbol starting with `rack_`, followed by the extension name and then followed by a question mark.

The value for the key-value pair **MUST** be an Array indicating the extensions version using [semantic versioning](https://semver.org).

i.e., if the extension name is "Metal" and the extension is version `"0.1.0-alpha.1"`, the key `e[:rack_metal?]` **MUST** be set to `[0, 1, 0, "alpha", 1]`.

## MiddleWare

Applications replacing the `e.handler` object **MUST** be aware that the MiddleWare might not be able to perform cleanup as the MiddleWare stack for the new handler might be different than the existing MiddleWare stack.

NeoRack MiddleWare is a Singleton Module or Class. It MUST delegate any unhandled method calls to the NeoRack Application and behave as if it were the application itself.

i.e.

```ruby
require 'forwardable'
class MiddleWare    
    def initialize(app); @app = app; end
    def on_http(event); @app.on_http(event); end
    def on_finish(event); @app.on_finish(event); end
    def call(env); @app.call(env); end # Rack extension
private
    def method_missing(method_name, *arguments)
        m = self.define_singleton_method(method_name) {|*args| @app.send(method_name, *args) }
        m.call(*arguments)
    end
end
```

MiddleWare **MAY** stop the request from reaching the application by calling either `e.finish` or `e.close` before the next MiddleWare or the application is called.

MiddleWare **SHOULD NOT** replace the `event` object with a new `event` object. Although this would allow the MiddleWare to control the application's behavior, it might cause unpredictable results.
