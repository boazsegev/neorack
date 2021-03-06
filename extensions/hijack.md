# Hijack Extension

Th NeoRack Hijack Extension describes a connection hijacking API that allows for backwards compatibility.

Servers that return a value from the `extensions[:hijack]` **MUST** conform to this extensions (or one of its versions).

## Extension Name

NeoRack Servers that implement this extension **MUST** set `extensions[:hijack]` so it is equal to `[0,1,0].freeze`.

NeoRack Servers that implement this extension **MUST** set `classes[:hijack]` to the class of the object returned by `response.hijack`.

## Response Methods

NeoRack Servers that implement this extension **MUST** implement the following methods in the `response` object.

#### `hijack(send_headers = false)`

**SHOULD** raise an exception if `response.streaming?` would have returned `true`.

**MUST** raise an exception if `response.finished?` would have returned `true`.

**MUST** cause future calls to `response.finished?` to return `true`.

Returns an IO like object that responds to the following methods in the same was a Ruby IO or Socket object would have responded: `fileno`, `read`, `write`, `close`, `read_nonblock`, `write_nonblock`, `flush`, `close_read`, `close_write`, `closed?`.

The `fileno` method is provided to allow implementations to `poll` the IO device and this feature **SHOULD** be supported. However, NeoRack Applications and other Extensions **MUST NOT** use `fileno` for anything else, as this might break some implementations. i.e., when the server supports HTTP/2 tunneling, writing or reading from the `fileno` will break the HTTP/2 protocol.

If `send_headers` is `true`, the Server **MUST** send the status and headers before returning the IO object.

**Note**: unless the server handles the IO object calls to `write` and `write_nonblock`, the status and header data must be completely written to the system's IO buffer before the `hijack` method can return.

## Recommendations

It is **RECOMMENDED** that NeoRack Applications and Extensions consider `hijack` as a last result solution.

It is **RECOMMENDED** that NeoRack Servers don't pass an actual IO object, but instead wrap the IO object in a container that handles as many IO concerns as possible.

Servers **SHOULD** do they're best to handle all network and protocol concerns and support extensions that will allow applications to remain blissfully unaware of network details.
