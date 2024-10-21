# NeoRack Compatibility with Rack

NeoRack backward compatibility with the [CGI-style Rack specifications](https://github.com/rack/rack/blob/master/SPEC.rdoc) is considered an extension and uses the reserved extension name `:rack`.

Implementations **MUST**:

- Set the server's `extensions[:rack]` value to the Rack specification version they support (e.g., `[1, 3, 0].freeze`).

- Populate all `env` values as specified in the [Rack specifications](https://github.com/rack/rack/blob/master/SPEC.rdoc).

- Implement a default `on_http` method in the NeoRack application passed to the server (if `on_http` is missing), so that `on_http` calls the application's `call(env)` method when a request is received.

- Handle the Rack response according to the Rack specifications and send it using the NeoRack event object as described in the NeoRack specification.

## NeoRack Event Instance

A NeoRack server `event` instance object (herein `e`) that supports this extension **SHOULD** respond to the following method:

- **`env`**: Returns a Rack-compliant `env` object in accordance with the [Rack specifications](https://github.com/rack/rack/blob/master/SPEC.rdoc).

A NeoRack server `event` instance object that supports this extension **MAY** respond to the following method:

- **`rack_hijack`**: Hijacks the connection and returns an IO (or IO-like) object that matches the Rack hijack extension requirements.

----

## Notes and Recommendations

The Event object was designed to allow it to fill certain aspects and requirements set in the [Rack specifications](https://github.com/rack/rack/blob/master/SPEC.rdoc), such as functioning as the Rack::IO for the request body.

It is recommended that a new Hash instance be used for the `env` and the Event instance (`e`) be stored in the `env` and used as needed.
