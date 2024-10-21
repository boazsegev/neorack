# WebSocket Extension

The WebSocket extension for NeoRack is designed to allow Neo-Rack applications to handle WebSocket connections.

This is an extension to the NeoRack specification and is in addition to the core features that **MUST** be implemented according to the NeoRack specification.

## Name and Version

NeoRack Servers supporting this extension **MUST** set this in their `extensions` Hash Map:

```ruby
Server.extensions[:ws] = [0,0,1]
```

## NeoRack WebSocket Applications

A NeoRack Applications that supports this extension **SHOULD** responds to the following methods:

* `on_authenticate_websocket(e)` - called INSTEAD of the `on_http` method. This method **MUST** return `true` **IF** the connection is allowed to proceed. Any other return value will cause the connection to be refused.

* `on_open(e)` - called when the WebSocket connection is established.

* `on_message(e, msg)` - called when a message is received. `msg` will be a String instance. **IF** the WebSocket message is a text message, the `msg` String **MUST** be UTF-8 encoded. Otherwise, the `msg` String **MUST** be Binary encoded.

* `on_close(e)` - called when the WebSocket connection is closed.

* `on_shutdown(e)` - called when the process to which this connection belongs starts shutting down (i.e., during hot restart or server shutdown). NeoRack Servers **MAY** choose to ignore this callback.

* `on_drained(e)` - called when all calls to `e.write` have been handled and the outgoing buffer is now empty. NeoRack Servers **MAY** choose to ignore this callback.

IF `on_authenticate_websocket` is missing, Servers **MUST** provide a default implementation that calls `on_authenticate` instead. If `on_authenticate` too is missing, Servers **MUST** provide a default implementation that returns `true` **ONLY IF** the application responds to either `on_open` or `on_message`.

### The `on_finish` callback timing

`on_finish` **MUST ALWAYS** be called by NeoRack Servers, or else cleanup may be too difficult to reason about.

When implementing this extension, NeoRack Servers **MUST** call `on_finish` after either a failed client authentication or after calling `on_close`.

Cleanup is at the end.

## The `event` Instance Object (herein `e`)

The following methods MUST be implemented by the `event` instance object:

* `e.websocket?` - returns `true` if the connection is a WebSocket connection.

* `e.open?` - returns `true` if the connection appears to be open and `close` hadn't been called (no known issues).

* `e.close` - schedules the connection to be closed once all calls to `e.write` had finished.

* `e.write(data)` - writes data to the connection or the connection's buffer.

    In general, `data` **SHOULD** be a String. The Server **SHOULD** send UTF-8 encoded Strings as text messages and Binary encoded Strings as binary messages.

    If `data` is NOT a String, the server **MAY** attempt to convert it to a JSON String, allowing Hashes, Arrays and other native Ruby objects to be sent over the wire.

    If `data` is an `IO` object the Server **MUST** close it at the appropriate time. Servers **MAY** choose to refuse IO objects to be used when sending data.

    `e.write` **MUST** return `true` if the data was written to the connection or the connection's buffer. `e.write` **SHOULD** return `false` if the data was not written (i.e., the connection is closed and writing is impossible), but **MAY** also throw an exception.

    **Note**: `e.write` is shared between HTTP, WebSocket and SSE connections. Servers **MUST** ensure that the `data` argument is handled correctly based on the connection type.

* `e.pending` - **SHOULD** return the number of bytes that need to be sent before the next `on_drained` callback is called. **MAY** return `true` instead of a number, if the outgoing buffer isn't empty. **Must** return `false` if the outgoing buffer is empty **OR** if the Server never calls `on_drained`.

## The Upgrade Process

When a successful connection upgrade had occurred, the `on_open` callback **MUST** be called before any `on_message` callbacks.

The HTTP `on_finish` callback should **NOT** be called by the Server after a successful upgrade. Instead, the Application **MAY** choose to call `e.handler.on_finish(e)`. This allows the Application to handle the HTTP request as it sees fit.

