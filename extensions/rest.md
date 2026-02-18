# REST Resource Extension

Extension for REST/CRUD-style resource routing in NeoRack applications.

The following is the **normative specification**:

```ruby
Server.extensions[:rest] = [0, 0, 2]

Server.instance_eval do
  # Converts handlers into REST resources with automatic routing.
  # @param handlers [Array<Module>] one or more resource handler modules
  # MUST raise if handler already defines on_http
  # MUST add on_http that routes to appropriate callback
  # MUST return 405 Method Not Allowed for unimplemented callbacks or unsupported HTTP methods
  # MUST handle HEAD requests as GET (without body)
  def make_resource(*handlers); end
end

# DSL method (REQUIRED if server implements DSL)
module Server::DSL
  # Registers resource handlers. MUST call Server.make_resource.
  def neorack_resource(*handlers)
    Server.make_resource(*handlers)
  end
end

# Resource handler callbacks (implement INSTEAD of on_http)
# All callbacks receive event (e) and MUST call e.finish.
# Unimplemented callbacks: MUST return 405 Method Not Allowed (resource exists, method not supported)
# Non-existent resources: MUST return 404 Not Found (e.g., invalid ID in show/edit/update/delete)
module ResourceHandler
  def self.index(e);   end  # GET /
  def self.show(e);    end  # GET /{id}         — id: e.path[1..-1]
  def self.new(e);     end  # GET /new          — form for new resource
  def self.edit(e);    end  # GET /{id}/edit    — id: e.path.split('/')[1]
  def self.create(e);  end  # POST|PUT|PATCH / or /new
  def self.update(e);  end  # POST|PUT|PATCH /{id}
  def self.delete(e);  end  # DELETE /{id}

  # (optional) All other NeoRack handler callbacks (on_http, etc') as fallback.
end
```

## Routing Table

`{id}` represents any non-empty path segment (one or more characters excluding `/`).

| HTTP Method    | Path        | Callback | ID Extraction |
|----------------|-------------|----------|---------------|
| GET, HEAD      | /           | index    | — |
| GET, HEAD      | /new        | new      | — |
| GET, HEAD      | /{id}       | show     | `e.path[1..-1]` |
| GET, HEAD      | /{id}/edit  | edit     | `e.path.split('/')[1]` |
| POST, PUT, PATCH | /         | create   | — |
| POST, PUT, PATCH | /new      | create   | — |
| POST, PUT, PATCH | /{id}     | update   | `e.path[1..-1]` |
| DELETE         | /{id}       | delete   | `e.path[1..-1]` |

Trailing slashes SHOULD be treated as equivalent (e.g., `/new` = `/new/`).

## Example Implementation

```ruby
Server.instance_eval do
  def make_resource(*handlers)
    handlers.each do |handler|
      raise "#{handler.name} already has on_http" if handler.respond_to?(:on_http)

      # Add default 405 for unimplemented callbacks (method not allowed)
      %i[index show new edit create update delete].each do |name|
        unless handler.respond_to?(name)
          handler.define_singleton_method(name) { |e| e.status = 405; e.finish }
        end
      end

      # Add routing via on_http
      handler.define_singleton_method(:on_http) do |e|
        # Normalize: e.method is uppercase per core spec
        method = e.method
        # Normalize path: strip trailing slash for comparison
        path = e.path.chomp('/')
        path = '/' if path.empty?

        action = case method
                 when 'GET', 'HEAD'
                   case path
                   when '/'      then :index
                   when '/new'   then :new
                   else
                     path.end_with?('/edit') ? :edit : :show
                   end
                 when 'POST', 'PUT', 'PATCH'
                   (path == '/' || path == '/new') ? :create : :update
                when 'DELETE'
                    :delete
                  else
                    nil  # Unknown HTTP method -> 405
                  end

        action ? send(action, e) : (e.status = 405; e.finish)
      end
    end
  end
end
```
