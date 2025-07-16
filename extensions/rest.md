# REST Resource Extension

The resource extension for NeoRack is designed to make it easier to author NeoRack applications that offer a REST/CRUD style API for any resources.

```ruby
Server.extensions[:rest] = [0,0,1]

Server.instance_eval do
    def make_resource(*handler_array) ; end
end

# Optional, if Server provides a CLI with a DSL
module Server::DSL
  def neorack_resource(*ha)
    Server.make_resource(*ha)
  end
end

# Scaffolding
module ResourceHandler
  def self.index(e);  e.status = 404; e.finish; end
  def self.show(e);   e.status = 404; e.finish; end
  def self.new(e);    e.status = 404; e.finish; end
  def self.edit(e);   e.status = 404; e.finish; end
  def self.create(e); e.status = 404; e.finish; end
  def self.update(e); e.status = 404; e.finish; end
  def self.delete(e); e.status = 404; e.finish; end
end

# Use:
neorack_resource(ResourceHandler)
```

## Name and Version

NeoRack Servers supporting this extension **MUST** set the correct value in their `extensions` Hash Map, as shown above.

## The Resource Handler / Application Callbacks

A NeoRack Resource Handler is a type of NeoRack Application and **MUST** respond to the following Callback methods **INSTEAD** of responding to the `on_http` method:

- The `index` method, which will be called for `"GET /"`.

- The `show` method, which will be called for `"GET /(id)"`, where `id` can be assumed to be: `e.path[1..-1]`.

- The `new` method, which will be called for `"GET /new"`, expecting a response containing a form for posting a new element.

- The `edit` method, which will be called for `"GET /(id)/edit"`, expecting a response containing a form for editing the existing element with `id` being `e.path.split('/')[1]`.

- The `create` method, which will be called for `"PATCH /"`, `"PUT /"`, `"POST /"`, `"PATCH /new"`, `"PUT /new"`, `"POST /new"` (`new` is optional).

- The `update` method, which will be called for `"PATCH /(id)"`, `"PUT /(id)"`, `"POST /(id)"`, where `id` can be assumed to be: `e.path[1..-1]`.

- The `delete` method, which will be called for `"DELETE /(id)"`, where `id` can be assumed to be: `e.path[1..-1]`.

| HTTP method | path       | Ruby method |
|-------------|------------|-------------|
| GET         | /          | index       |
| GET         | /new       | new         |
| GET         | /(id)      | show        |
| GET         | /(id)/edit | edit        |
| POST        | /          | create      |
| PUT         | /          | create      |
| PATCH       | /          | create      |
| POST        | /new       | create      |
| PUT         | /new       | create      |
| PATCH       | /new       | create      |
| POST        | /(id)      | update      |
| PUT         | /(id)      | update      |
| PATCH       | /(id)      | update      |
| DELETE      | /(id)      | delete      |

### NeoRack Server Methods

NeoRack Servers supporting this extension **MUST** implement the `make_resource` method above.

For each `handler` passed to the method, the method **MUST**:

1. Raise an exception if `on_http` was previously defined for `handler`;

1. add an implementation for `on_http` that will route each request to the appropriate Ruby `handler` callback method; and

1. Return a `404 not found` response for any Callback method not implemented.


### DSL Methods

A NeoRack Server that both supports this extension and implements a DSL (for `config.nru` / `config.ru` files) **MUST** support the `neorack_resource`.

`neorack_resource` **MUST** call the Server's `make_resource` method on each handler object it receives.

### Mock Approach

The following is one way this extension could be implemented (untested):

```ruby
unless Server.extensions[:rest]
  Server.extensions[:rest] = [0,0,1]
  Server.instance_eval do
    def make_resource(*ha)
      ha.each do |handler|
        if handler.respond_to?(:on_http)
          raise "Handler #{handler.name} can't be a resource, it already has an on_http callback"
        end
        [:index, :show, :new, :edit, :create, :update, :delete].each do |name|
          unless handler.respond_to?(name)
            handler.define_method(name) {|e| e.status = 404; e.finish }
          end
        end
        handler.define_method(:on_http) do |e|
          # routing logic here.
          name = nil
          if(e.method.downcase == 'get')
            if (e.path.length == 4 && e.path == '/new') ||
              e.path.start_with?('/new/')
              name = :new
            elsif e.path.end_with?('/edit') || e.path.end_with?('/edit/')
              name = :edit
            elsif e.path.length > 1
              name = :show
            else
              name = :index
            end
          elsif (e.method.downcase == 'put'  ||
                 e.method.downcase == 'post' ||
                 e.method.downcase == 'patch')
            if e.path.length < 2 ||
              (e.path.length == 4 && e.path == '/new') ||
              e.path.start_with?('/new/')
              name = :create
            else
              name = :update
            end
          elsif (e.method.downcase == 'delete')
            name = :delete
          end
          if name
            self.__send_(name, e)
          else
            e.status = 404
            e.finish
          end
        end
      end
    end
  end
  neorack_resource = Serve.method(:make_resource)
end
```
