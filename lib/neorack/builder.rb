module NeoRack
  # A single application NeoRack application DSL script handler.
  #
  # Use the {NeoRack::Builder.load} methods for loading scripts.
  class Builder
  	# NOTE: Internal names end with `___` to minimize possible namespace concerns.

    # Initializes a new builder object and run the script in filename
    def initialize(server, script, filename)
      @server___, @app___, @warmup___, @app___= server, nil, nil, nil
      @stack_pre___, @stack___, @stack_post___  = [].dup, [].dup, [].dup
      # run script in context of the object, enabling the DLS
      instance_eval(script, filename)
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
      @stack_post___.reverse!
      @warmup___.call(@app___) if @warmup___
      [@stack_pre___, @app___, @stack_post___]
    end

    # Returns a three member Array containing the setup callback stack (Array), the application object and the cleanup callback stack (Array).
    #
    # On script loading failure (i.e., file name doesn't exist), returns `nil`.
    #
    # Note: may raise an exception if the script itself raises an exception.
    #
    # Use:
    #
    #     pre_request, app, post_request = *NeoRack::Builder.load(MyServerClass, 'config.ru')
    #     raise "MyServer couldn't find 'config.ru'" unless app && pre_request && post_request
    #
    def self.load(server_klass, filename = 'config.ru')
    	# try to load the file
      script = ::File.read(filename) rescue nil
      return `nil` unless script
      # remove UTF-8 BOM, see: https://stackoverflow.com/questions/2223882/whats-the-difference-between-utf-8-and-utf-8-without-bom
      script.slice!(0..2) if script.encoding == Encoding::UTF_8 && script.start_with?('\xef\xbb\xbf')
      # start a new builder
      instance = NeoRack::Builder.new(server_klass, script, filename)
      # build stack and return
      instance.build_stack___
    end
  end
end
