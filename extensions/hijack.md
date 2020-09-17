# Hijacking Extension

This NeoRack extension describes a connection hijacking API that allows for backwards compatibility.

## Extension Name

NeoRack Servers that implement this extension **MUST** set `extensions[:hijack]` to it is equal to `[1,0,0].freeze`.

NeoRack Servers that implement this extension **MUST** set `classes[:hijack]` to the class of the object returned by `response.hijack`.

## Response Methods

NeoRack Servers that implement this extension **MUST** implement the following methods in the `response` object.

#### `hijack(send_headers = false)`

**MUST** raise an exception if either `response.streaming?` or `response.finished?` would have returned `true`.

**MUST** cause `response.finished?` to return `true`.

Returns an IO like object that responds to the following methods in the same was a Ruby IO or Socket object would have responded: `fileno`, `read`, `write`, `close`, `read_nonblock`, `write_nonblock`, `flush`, `close_read`, `close_write`, `closed?`.

The `fileno` method is provided to allow implementations to `poll` the IO device and this feature **SHOULD** be supported.

If `send_headers` is `true`, the Server **MUST** send the status and headers before returning the IO object.

**Note**: unless the server handles the IO object calls to `write` and `write_nonblock`, the status and header data must be completely written to the system's IO buffer before the `hijack` method can return.

## Recommendations

It is **RECOMMENDED** that NeoRack Applications and Extensions consider `hijack` as a last result solution.

It is **RECOMMENDED** that NeoRack Servers don't pass an actual IO object, but instead wrap the IO object in a container that handles as many IO concerns as possible.

Servers **SHOULD** do they're best to handle all network and protocol concerns and support extensions that will allow applications to remain blissfully unaware of network details.
