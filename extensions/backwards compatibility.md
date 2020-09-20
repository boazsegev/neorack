# NeoRack Compatibility with Rack

NeoRack backwards compatibility with [the CGI style Rack specifications](https://github.com/rack/rack/blob/master/SPEC.rdoc) is considered an Extension and uses the reserved extension name `:backwards_compatible`.

Implementations **MUST**:

* Set the Server's `extensions[:backwards_compatible]` values to the Rack protocol version they support (i.e., `[1,3,0].freeze`).

* Set all `env` values as set in the [CGI style Rack applications](https://github.com/rack/rack/blob/master/SPEC.rdoc).

* Set `env['neorack.request']` to the `request` object.

* Set `env['neorack.response']` to the `response` object.

* Bridge any supported NeoRack extensions that have Rack equivalents (i.e., `hijack`).

* Correctly handle cases in which the backwards compatible application uses the `response` object directly.

Implementations **SHOULD** use the `request` object for implementing the Rack style `env`.

## Example Implementation

The following is an example for an external backwards compatibility extension, it is untested, might not work and should be considered pseudo code.

Actual implementation are not restricted to the following approach.

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
