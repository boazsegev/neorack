# NeoRack Compatibility with Rack

NeoRack backwards compatibility with [the CGI style Rack specifications](https://github.com/rack/rack/blob/master/SPEC.rdoc) is considered an Extension and uses the reserved extension name `:rack`.

Implementations **MUST**:

* Set the Server's `extensions[:rack]` values to the Rack specification version they support (i.e., `[1,3,0].freeze`).

* Set all `env` values as set in the [Rack SPECs](https://github.com/rack/rack/blob/master/SPEC.rdoc).

* Implement the `on_http` method so it calls the Application's `call(env)` when a request is received.

* Handle the Rack response according to the Rack specifications and send it using the NeoRack event object as described in the NeoRack specification.

## NeoRack Event Instance

A NeoRack Server `event` instance object (herein `e`) that supports this extension **MAY** respond to the following method:

* `rack_hijack` - hijacks the connection and returns an IO (or IO-like) object that matches the Rack hijack extension requirements.
