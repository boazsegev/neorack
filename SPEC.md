# NeoRack Specification

NeoRack define a protocol / API for web application servers and applications to communicate with each other.

The following are the NeoRack Application, Server and Extension specifications.

NeoRack Applications, Servers and Extensions **MUST** follow in order to be considered conforming.

Note that NeoRack Applications, Servers and Extensions are **NOT** required to include any specific NeoRack related gem in order to conform to these specifications.

## NeoRack Applications

A NeoRack application is any Ruby object that responds to the method `call` where the `call` method accepts two arguments (`request`, `response`). i.e.,

```ruby
APP = Proc.new {|request, response| response << "Hello World" }
```

For backwards compatibility reasons, a NeoRack Application that returns while both `response.streaming?` and `response.finished?` would return `false` **SHOULD NOT** return an `Array` instance object as its final value - otherwise the returned value might be processed.

If both `response.streaming?` and `response.finished?` return `false` after the Application returns, the Server **MUST** call `response.finish`.

i.e., in pseudo code:

```ruby
r = APP.call(request, response)
unless response.streaming? || response.finished?
  process_backwards_compatible_response(r) if r.is_a?(Array)
  response.finish
end
```

## The NeoRack Request Object

The NeoRack Request Object (`request`) **SHOULD** be an instance of a class that inherits from `Hash` (but is **NOT** an instance of `Hash`) and **MUST** implement the following "Hash-like" methods: `[]`, `[]=`, `each`, `size`, `has_key?` and `merge!` in the same way they are implemented by `Hash`.

The `request` object **MAY** be used by Applications and/or Extensions to store and/or communicate additional data relevant to the request.

**Note**: during Server initialization, an application might `extend` or `include` its own modules into the Server's Request class. For this reason it is better if that class is not the Hash class itself.

### Request methods

The `request` object **MUST** respond to the following methods:

#### `server`

Returns the Server class / object that called the Application object.

### Request key-value pairs

The Server **MUST** set following key-value pairs in the NeoRack Request object. All keys are Symbols (not Strings).

#### `:VERSION_SPEC`

The version for this specification as a three member Array of Numbers, currently `[0,0,1]`.

#### `:VERSION`

The HTTP version String as reported by the client. For HTTP/2 and HTTP/3 (QUIC) use `'HTTP/2'` and `'HTTP/3'` respectively.

#### `:secure`

**MUST** be set to false unless the server itself handles TLS/SSL encryption for this request / connection.

#### `:scheme`

Depending on the request URL and environment, usually `http`, `ws`, `https` or `wss`.

#### `:method`

The HTTP method used for the request, set as a String instance (`'HEAD'`, `'GET'`, `'POST'`, `'UPDATE'`, etc').

#### `:query`

The portion of the request URL that follows the `'?'`, if any. **MUST** be a String (even if empty).

#### `:path`

The portion of the request URL before the query and after the host name and optional authentication details.

**MUST** be a String. **MUST** start with the `'/'` character (even if the original path was an empty String).

Servers that support multiple Application objects **MAY** change this value in a documented manner.

#### `:path_root`

The portion of the request URL path that was extracted from the beginning of the `:path` String or an empty String.

**MUST** be a String (even if empty).

**MUST NOT** end with `'/'`.

Unless empty, **MUST** start with a `'/'`.

Servers that support multiple Application objects **SHOULD** document how `path_root` is used.

**Note**: it **MUST** be possible to construct a valid URL that routes to the same Application object using:

```ruby
url = "#{request[:scheme]}://#{request['host']}#{request[:path_root]}#{request[:path]}?#{request[:query]}"
```

#### `:body`

An HTTP payload (body) object (see details further on).

If a payload exists, this value **MUST** be set. Otherwise this **MAY** be set to `nil`, left unset or point to an empty body object.

### HTTP Request Headers

All HTTP headers, **MUST** be set as key-value pairs in the `request` where the key is a **String** and the value is either a String or an Array of Strings.

Header names **MUST** be converted into their lower case equivalent before the key-value pair is set (i.e., `"Content-Length"` MUST be converted to `"content-length"`).

Unless the Server implements the `:backwards_compatible` extension (see further on), HTTP headers **MUST** be the **ONLY** String keys in the `request` set by the Server or by any of its Extension. Otherwise, it might make it impossible to implemented a `:backwards_compatible` extension.

When a header arrives only once, it's value **MUST** be set as a String instance object.

Headers that arrive more than once **SHOULD** be set as an Array of Strings, ordered by header value arrival (i.e., `headers['cache-control'] = ['no-cache', 'no-store']`)

**ONLY IF** [the HTTP protocols allows for this variation](https://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.2), Servers **MAY** also merge header values into a single comma separated value String instance or separate a single header into an Array of Strings.

NeoRack Applications and Extensions **MUST** be prepared to handle both variations (Array / String).

### HTTP Request Body

The NeoRack Request Body (`request[:body]`) is an IO-like object which contains the raw HTTP POST data (payload / body). It is backwards compatible with the original Rack specification with the addition of the methods `length`.

When no HTTP payload / body was received, `request[:body]` **SHOULD** be `nil`, but **MAY** be a Request Body Object that maps to an empty String.

The `request[:body]` object (if set) **MUST** respond to IO style methods `gets`, `each`, `read`, `rewind` and `length`. These methods **MUST** behave the same way as described by [the Ruby IO documentation](https://ruby-doc.org/core-2.7.1/IO.html). The following clarifications were pretty much copied from [the original Rack specification](https://github.com/rack/rack/blob/master/SPEC.rdoc):

#### `gets`

**MUST** be called without arguments and Reads the next "line" from the body object. It returns either a String (on success), or `nil` (on `EOF`).

#### `read(length = nil, buffer = nil)`

If given, `length` **MUST** be a non-negative Integer (>= 0) or `nil`,

If `length` is given and not `nil`, then this method reads at most `length` bytes from the body object.

If `length` is not given or `nil`, then this method reads all data until `EOF`.

When `EOF` is reached, this method returns `nil` if `length` is given and not `nil`, or `""` if `length` is not given or is `nil`.

If given, `buffer` **MUST** be a String.

If `buffer` is given, then the read data will be placed into `buffer` instead of a newly created String object.

#### `each`

**MUST** be called without arguments and only yield one String instance object per iteration.

#### `rewind`

**MUST** be called without arguments. It rewinds the body object back to the beginning. It **MUST NOT** raise `Errno::ESPIPE`: that is, it may not be a pipe or a socket. Therefore, developers **MUST** buffer the input data into some rewindable object if the underlying body object is not rewindable.

#### `length`

Returns the length of the data in the body object.

**Note**: Applications **SHOULD NOT** access the `'content-length'` header using the request object and **SHOULD** prefer to access this data using the `request[:body]` object (`request[:body].length`).

#### `close`

**MUST NOT** be called on the body object except by the Server.

## The NeoRack Response Object

The NeoRack Response Object (`response`) manages the response data, including the response status, header data and body (payload).

### NeoRack Response Methods

The NeoRack Response Object **MUST** respond to the following methods: 

#### `status`

Returns the response status.

#### `status=`

Sets the response status.

**SHOULD** raise an exception if either `streaming?` or `finished?` would have returned `true`.

#### `add_header(name, value)`

Adds a header to the response. If the header exists, the header will be sent multiple times (i.e., `'set-cookie'`).

If either `name` or `value` are `nil`, does nothing (returns, no exception is raised).

`name` and `value` **MUST** be either `nil`, a String object or a Number. Otherwise an `ArgumentError` exception **MUST** be raised.

The header `name` **SHOULD** be lowercase, but Servers **SHOULD** expect application to be inconsistent in this regard.

The Server **MAY** perform any additional action, such as sending an *Early Hints* responses or invoking an HTTP/2 *push promise* request for `'link'` headers, attempt to auto-correct or rewrite header data, etc'. Such behavior **SHOULD** be documented.

**MUST** raise an exception if either `streaming?` or `finished?` would have returned `true`.

#### `reset_header(name, value = nil)`

If `name` is `nil`, does nothing (returns, no exception is raised).

Deletes the header from the response if the header exists.

If `value` is set, calls `add_header(name, value)`

**MUST** raise an exception if either `streaming?` or `finished?` would have returned `true`.

#### `set_cookie(name, value, options={})`

If `name` is `nil`, does nothing (returns, no exception is raised).

If `value` is `nil`, sets the cookie to be deleted.

If both `name` and `value` are set, adds a cookie to the response. If the cookie exists, it is overwritten.

**MUST** raise an exception if either `streaming?` or `finished?` would have returned `true`.

Servers **SHOULD NOT** encode cookie data (names / value). Encoding the data is the Application's responsibility and choice.

`name` and `value` **MUST** be either `nil` or a String object. Otherwise an `ArgumentError` exception **MUST** be raised. **Note**: empty String objects are valid, but **SHOULD** be avoided by the Applications.

If `name` is an invalid cookie name or `value` is an invalid cookie value, behavior is undefined (see [here](https://tools.ietf.org/html/rfc6265) and [here](https://stackoverflow.com/questions/1969232/what-are-allowed-characters-in-cookies)). The Server **MAY** attempt to auto-correct the issue, raise and exception, quietly fail, drop the connection, etc'.

The `option` hash **MUST** recognize the following Symbols for setting cookies (see also the [`Set-Cookie` header details](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie)):

* `:path`       - (String) A path that must exist in the requested URL, or the browser won't send the Cookie header.

* `:domain`     - (String) The domain for which this cookie applies. Valid a specific domain String object (i.e. `'example.com'`). Note that subdomains are always allowed.

* `:same_site`  - (Boolean) If set, **MUST** be either `:strict`, `:lax` or `:none`. [Read details here](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie).

* `:secure`     - (Boolean) A secure cookie is only sent to the server when a request is made with the `https` scheme.

* `:http_only`  - (Boolean) If `true`, forbids JavaScript from accessing the cookie through a script (i.e, using `document.cookie`).

   **Note**: The cookie is still sent with JavaScript originated requests. 

* `:max_age`    - (Number) The number of seconds until the cookie expires. A zero or negative number will expire the cookie immediately.

* `:expires`    - (Number / Time) **SHOULD** be considered deprecated by Application developers. It is only provided for compatibility purposes.

    `:expires` is the maximum "due date" lifetime for the cookie as either a number (Unix style time stamp) or a Ruby Time instance object. If provided, servers **MUST** translate the time stamp into an HTTP Date format.

    If both `:max_age` and `:expires` are set, `:max_age` **MUST** be preferred and `:expires` **SHOULD** be ignored. Servers **MAY** send both values (`Max-Age` always has precedence).

    If only `:expires` is set, the Server **MAY** convert `:expires` to `:max_age` values.

**Note**: if both `:max_age` and `:expires` are missing, the cookie will be considered a session cookie by the client.

#### `write(data, offset = 0, length = nil)`

**MUST** raise an exception if `finished?` would have returned `true`.

If `streaming?` is `false`, the Server **MUST**:

* Add the data to be sent to the response payload (body), unless `request[:method] == 'HEAD'`.

If `streaming?` is `true`, the Server **MUST**:

* Unless previously performed:

    * Update the `'transfer-encoding'` header as required by the protocol, unless the `'content-length'` header was previously set or the server knows the final length of the data to be sent.

    * Validate and send the status and header data.

* If `request[:method] == 'HEAD'`, return at this point without further processing.

* Add the data to be sent to the response payload (body).

* Send any pending data in the response payload / body (or schedule to do so) using the proper encoding scheme (streaming responses my need to be `chunked`).

**Note**: depending on their design, Servers **MAY** block to until the data was actually sent through the socket.

Returns `self` (the `response` object).

`data` **MUST** either:

* Be a String instance object.

* Respond to both `to_path` and `close`, allowing the Server to `close` the object and send it from disk (possibly in that order).

* Respond to both `fileno` and `close`, allowing the Server to take ownership of the IO device and stream it.

If `offset` is set, the first `offset` bytes in the `data` object are ignored (not sent). `offset` **MUST** be a Number.

If `length` is set, up to `length` bytes from the `data` object will be sent. `length` **MUST** be either `nil` or a Number.

Servers **MUST** test the `length` value for overflow whenever possible (may not be always possible). If `length` overflows it is **NOT** an error, but it could cause network errors that the Server **MUST** properly handle or require that the response be streamed.

#### `<<`

The `<<` method is an alias to `write`.

#### `stream`

**MUST** raise an exception if `finished?` would have returned `true`.

Sets the response to streaming.

Returns `self` (the `response` object).

If `write` was previously called, **MUST** perform all necessary operations as if the call to `write` was performed after the call to `stream` - i.e., update the proper `'transfer-encoding'` header, validate and send the status and header data, etc'.

#### `streaming?`

**MUST** return `false` unless both `stream` was previously called and `finished?` is `false`.

Otherwise, **MUST** return `true`.

#### `finish(data = nil, offset = 0, length = nil)`

**SHOULD** raise an exception if `finished?` would have returned `true`, but **MAY** quietly fail without doing anything.

The Server **MUST**:

* Call `write` if `data` isn't `nil`.

   **Note**: if `stream` was previously called but no data was previously sent (`write` wasn't called previously), the Server **SHOULD** behave as if the `stream` method was never called (i.e., set `'content-length'` rather than stream, if possible).

* Unless previously performed, validate and send the status and header data.

* Unless `request[:method] == 'HEAD'`, send any pending data in the response payload / body (or schedule to do so) using the proper encoding scheme.

* Call (or schedule) all the `run_after` callbacks.

#### `finished?`

**MUST** return `false` **unless** either `finish` or `cancel` were called.

Otherwise, **MUST** return `true`.

#### `cancel(error_code)`

Cancels the response object, returning the response management to the Server.

If possible, the Server **MUST** send an appropriate error response.

**SHOULD** raise an exception if `error_code` is less than 400 or grater than 599 (`< 400 || >= 600`).

**MUST** raise an exception if either `streaming?` or `finished?` would have returned `true`.

## NeoRack Servers

A NeoRack Server **MUST**, at the very least, handle network and HTTP protocol details to the minimal level required to implement the NeoRack `request` and  NeoRack `response` objects and call a NeoRack Application object.

A NeoRack Server **MUST** accept at least one NeoRack Applications and forward a `request` and `response` object to the Application.

If a NeoRack Server accepts more than a single NeoRack Application, the Server **SHOULD** document how it selects the Application object.

Servers **SHOULD** implement the `hijack` extension if possible. It **SHOULD NOT** be used by applications, but it often is.

### Server methods

A NeoRack Server **MUST** implement the following methods in the Server object returned by a call to `request.server`:

#### `forking?`

**MUST** be set to `true` **ONLY IF** the Server's concurrency model expects to use `fork` (i.e., workers processes or a process-per-connection). If this is not the case, returns `false`.

This allows Extensions and Applications know if some features require IPC (Inter Process Communication).

#### `blocking?`

**MUST** be set to `true` **ONLY IF** the Server's concurrency model allows execution to block without negative side-effects, i.e., process/thread/fiber-per-connection design patterns.

#### `extensions`

Returns a Hash object that maps extension name Symbols to version number arrays. **MAY** be an empty Hash.

Version number arrays **MUST** be frozen Array who's first three members are Numbers that follow [semantic versioning](https://semver.org).

i.e.: `request[:SERVER].extensions[:rack_compatible] # => [1,3,0]`

#### `classes`

Returns a Hash object where Symbol keys are mapped to Class objects (not Class instances).

The Server MUST set the following key-value pairs:

* `:request` **MUST** map to the Class used for the Server's `request` objects.

* `:response` **MUST** map to the Class used for the Server's `response` objects.

* `:concurrency` **MUST** map to either `Thread` or `Fiber`, allowing the Server to hint at the preferred way for the Application to handle concurrent processing. Servers **SHOULD** set this value to `Thread` unless they are `Fiber` scheduling aware.

This **MAY** be used to test for and implement extensions. i.e.:

```ruby
# an Application could call this or a similar line using the DSL (see later) to add features to the Response object
server.classes(:response).include MyNeoRackHelpers unless server.extensions[:common_helpers] && server.extensions[:common_helpers][0] == 1
```

Extensions to this specification **MAY** require additional names to be added as long as these names are unique.

## NeoRack Extensions

NeoRack Servers **MAY** be extended either internally, through the Server supporting an extension, or externally, through setting up middleware and/or adding mixins to the published classes and updating the Server's `extensions` and `classes`.

Extensions registered in the NeoRack repository will have their specifications published in the `extensions` folder and **MUST** specify a unique name for the Servers `extensions` Hash, specify a [semantic versioning](https://semver.org) compliant 3 numbered version array and be mature.

Developers may also ask to register extension drafts to be placed in the `extensions/drafts` folder and request community feedback.

### External Extensions

External extensions **SHOULD** implement a `register` method that accepts at least one argument - the `self` object of the DSL execution environment.

The following is a made-up logging extension implementation example that should be considered as pseudo code (and is actually "middleware" in nature):

```ruby
# Place module somewhere
module MyLoggingExtension
  # registers the extension from the DLS
  def self.register(dsl)
    return if server.extensions[:logging_example]
    dsl.server.extensions[:logging_example] = [0,0,1]
    dsl.run_before(self.method :on_start)
    dsl.run_after(self.method :on_finish)
  end
  # Marks time
  def self.on_start(request, response)
    request[:STARTED_AT] = Time.now
  end
  # Prints log
  def self.on_finish(request)
    delta = Time.now - request[:STARTED_AT]
    puts "HTTP request %s%s took %.4fs"%(request[:path_root], request[:path], delta)
  end
end

# in the DSL, require the module and perform:
MyLoggingExtension.register(self)
```

## Starting up a NeoRack Server and Application

A NeoRack Server **MUST** document its startup and shutdown procedures.

A NeoRack Server **MAY** offer a Ruby API for setting up and/or running and/or managing the Server from within Ruby.

A NeoRack Server **SHOULD** implement a CLI (Command Line Interface) and **SHOULD** expose as many options through its CLI, minimizing the need for server specific setup files / code.

### Common CLI Arguments

If provided, the CLI **MUST** be able to load a Ruby script as detailed in the **NeoRack Application Scripts** section. The default script name is `'config.ru'`.

It is **RECOMMENDED** that Servers automatically test for the `ADDRESS` and `PORT` environment variables if those aren't set by the command line.

It is **RECOMMENDED** that Servers recognize the first unnamed CLI option as a the script name for the NeoRack application.

The following common CLI option names are **RECOMMENDED** (but to each their own):

* `-b` - the address to listen to.

* `-p` - the port number to listen to.

* `-D` - log Debug messages, if any.

* `-url` - possible alternative to the `-b` and `-p`, allowing a URL type address for the address and port binding.

* `-l` - log HTTP requests once the response was sent (finished), if supported.

* `-k` - sets HTTP keep-alive timeout in seconds.

* `-maxbd` - sets the approximate HTTP upload limit in Mb.

* `-maxhd` - sets the approximate total header length limit per HTTP request in Kb.

* `-t` - if multi-threaded mode is supported, sets the number of threads to be used.

* `-w` - if a process worker pool is supported, sets the number of worker processes to be used.

### NeoRack Application Scripts

NeoRack Servers **SHOULD** support loading NeoRack Applications using a Ruby script (i.e., `'config.ru'`).

When loading such a script, the following methods **MUST** be made available to the script as if they were global methods (a DSL):

#### `server`

Returns the Server object, allowing access to the Server methods.

#### `run(application)` 

Sets the NeoRack Application object for the current Script.

#### `run_before(proc_obj = nil, &block)`

This may be used for pre-request logic, such as authentication, database connection checkout, etc'.

Either the `proc_obj` or `block` **MUST** respond to `call(request, response)`.

Only on of these objects (`proc_obj` or `block`) will be used. `proc_obj` has precedence.

The NeoRack Server **MUST** call the object **before** calling the Application.

If `response.finished?` is `true` after the Server called the object, the server **MUST** stop processing the request.

#### `run_after(proc_obj = nil, &block)`

This may be used for cleanup logic, such as removing database connections from the `request` Hash, logging, etc'.

Either the `proc_obj` or `block` **MUST** respond to `call(request)`.

Only on of these objects (`proc_obj` or `block`) will be used. `proc_obj` has precedence.

The NeoRack Server **MUST** call the object (or schedule it) when `response.finish` is called.

#### `use(middleware, *args, &block)`

Provided for for backwards compatibility with a nested middleware design pattern.

#### `warmup(proc_obj = nil, &block)`

Provided for for backwards compatibility, takes a block and/or Proc object that will be called with the final Application object.

#### Example Application Script Loader

i.e.:

```ruby
module NeoRack
  # A single application NeoRack application DSL script handler 
  #
  # Internal names end with `___` to minimize possible namespace concerns.
  class Builder
    # initialize a new builder object and run the script in filename
    def initialize(server, filename = 'config.ru')
      @server___, @app___, @warmup___, @app___= server, nil, nil, nil
      @stack_pre___, @stack___, @stack_post___  = [].dup, [].dup, [].dup
      script = ::File.read(filename)
      # remove UTF-8 BOM, see: https://stackoverflow.com/questions/2223882/whats-the-difference-between-utf-8-and-utf-8-without-bom
      script.slice!(0..2) if script.encoding == Encoding::UTF_8 && script.start_with?('\xef\xbb\xbf')
      # run script in context of the object, enabling the DLS
      instance_eval(script)
    end

    # DSL method - access the Server object and its methods
    def server
      @server___
    end

    # DSL method - set the application to be used by the Script
    def run(application)
      # add middleware to a middleware stack
      @app___ = application
      self
    end

    # DSL method - runs `.call(request, response)` before the application handles the response.
    #
    # Used pre-request logic, such as authentication, database connection checkout, etc'.
    def run_before(prc = nil, &block)
      prc ||= block
      raise(ArgumentError, "this method requires an object that responds to `call(request, response)`") unless(prc.respond_to?(:call))
      @stack_pre___ << prc
      self
    end

    # DSL method - runs `.call(request)` after the response ended (when steaming, this is delayed until streaming ends).
    #
    # Used for cleanup logic, such as removing database connections from the `request` Hash, logging, etc'.
    def run_after(prc = nil, &block)
      prc ||= block
      raise(ArgumentError, "this method requires an object that responds to `call(request, response)`") unless(prc.respond_to?(:call))
      @stack_pre___ << prc
      self
    end

    # DSL method for backwards compatibility 
    def use(middleware, *args, &block)
      # add middleware to a middleware stack
      @stack___ << [middleware, args, block]
      self
    end

    # DSL method for backwards compatibility 
    def warmup(prc = nil, &block)
      @warmup___ ||= prc || block
    end

    # Internal use: returns the setup callback stack, the application object and the cleanup callback stack.
    def build_stack___
      raise "Application object missing!" unless @app___
      @stack___ << @app___
      app = @stack___.pop
      tmp = nil
      while((tmp = @stack___.pop))
        if tmp[3]
          app = tmp[0].new(app, *tmp[1], &tmp[2])
        else
          app = tmp[0].new(app, *tmp[1])
        end
      end
      @app___ = app

      @warmup___.call(@app___) if @warmup___
      [@stack_pre___, @app___, @stack_post___]
    end

    # returns the setup callback stack, the application object and the cleanup callback stack.
    def self.load(server_klass, filename)
      instance = NeoRack::Builder.new(server_klass, filename)
      instance.build_stack___
    end
  end
end
```

## NeoRack Compatibility with Rack

NeoRack backwards compatibility with [the CGI style Rack specifications](https://github.com/rack/rack/blob/master/SPEC.rdoc) is considered an Extension and uses the reserved extension name `:backwards_compatible`.

Backwards compatibility extensions **MUST**:

* Set all `env` values as set in the [CGI style Rack applications](https://github.com/rack/rack/blob/master/SPEC.rdoc).

* Set the Server's `extensions[:backwards_compatible]` values to the Rack protocol version they support (i.e., `[1,3,0].freeze`).

* Set `env['neorack.request']` to the `request` object.

* Set `env['neorack.response']` to the `response` object.

Backwards compatibility extensions **SHOULD** use the `request` object for implementing the Rack style `env`.

The following is an example for an external backwards compatibility extension, it is untested, might not work and should be considered pseudo code:

```ruby
# place this extension code somewhere
module NeoRack
  class BackwardsCompatibility
    def self.register(dsl)
      unless dsl.server.extensions[:backwards_compatible] && dsl.server.extensions[:backwards_compatible][0] == 1
        dsl.server.extensions[:backwards_compatible] = [1,3,0].freeze
        dsl.use(self)
      end
    end
    def initialize(app)
      @app = app
    end

    def call(request, response)
      add_old_env_values_to_request(request, response)
      old = @app.call(request)
      process_old_return_value(old, response)
    end

    # example implementation
    def self.add_old_env_values_to_request(request, response)
      new_headers = {}
      request.each do |k,v|
        if (k.is_a?(String) && k[0].ord >= 'a'.ord && k[0].ord <= 'a'.ord)
          if k == 'content-length' || k == 'content-type'
            new_headers[k.swapcase.gsub!('-', '_')] ||= v
          else
            new_headers["#{HTTP_}#{k.swapcase.gsub('-', '_')}"] ||= v
          end
        end
      end
      request.merge! new_headers
      # set whatever Rack requires... i.e.:
      request['REQUEST_METHOD']   = request[:method]
      request['rack.url_scheme']  = request[:scheme]
      request['SERVER_NAME']      = request['host']
      request['SCRIPT_NAME']      = request[:path_root]
      request['PATH_INFO']        = request[:path]
      request['QUERY_STRING']     = request[:query]
      request['rack.version']     = [1,3,0]
      request['rack.errors']      = STDERR
      if request[:body]
        request['rack.input']       = request[:body]
        request['CONTENT_LENGTH']   = request[:body].length.to_s
        request['CONTENT_TYPE']   = request[:body].type if request[:body].type
      else
        request['rack.input']     = StringIO.new
      end
      # allow NeoRack aware apps access to these objects
      request['neorack.request']  = request
      request['neorack.response'] = response
      # support hijack if supported
      if(request.server.extensions[:hijack])
        request['rack.hijack']     = Proc.new { request['rack.hijack_io'] = response.hijack(false) }
        request['rack.hijack?']    = true
      end
    end

    # example implementation 
    def self.process_old_return_value(old, response)
      # do nothing if it was already done.
      return nil if(response.finished? || response.streaming?)
      raise "unexpected return value from application" unless (old.is_a?(Array) && old.length == 3)
      # set status
      response.status = old[0].to_i
      # copy headers to new response object
      hijacked = old[2].delete('rack.hijack')
      old[1].each {|name, val| val = val.split("\n"); val.each {|v| response.add_header(name, v)} }
      # handle hijacking or send body
      if(hijacked && request.server.extensions[:hijack])
        hijacked.call(response.hijack(true))
      else
        case old[2].class
        when String
          response << str
          old[2].close if old[2].respond_to?(:close)
        when Array
          old[2].each {|str| response << str }
          old[2].close if old[2].respond_to?(:close)
        else
          # start streaming the response
          response.stream
          # perform `each` in a new thread / fiber, as it may block the server
          if(old['neorack.request'][:SERVER].blocking?)
              old[2].each {|str| response << str }
              response.finish
          else
            old['neorack.request'][:SERVER].classes[:concurrency].new do
              old[2].each {|str| response << str }
              response.finish
            end
          end
        end
      end
    end
  end
end

# run this code in the DSL
NeoRack::BackwardsCompatibility.register(self)
APP = Proc.new {|env| [200, {}, ["Hello World"]] }
run APP
```
