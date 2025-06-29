# Server Source Events (Event Source) Extension

The SSE extension for NeoRack is designed to allow Neo-Rack applications to handle SSE connections.

This is an extension to the NeoRack specification and is in addition to the core features that **MUST** be implemented according to the NeoRack specification.

## Name and Version

NeoRack Servers supporting this extension **MUST** set this in their `extensions` Hash Map:

```ruby
Server.extensions[:sse] = [0,0,1]

module NeoRackApp
    def on_authenticate_sse(e)          ; end
    def on_open(e)                      ; end
    def on_eventsource_reconnect(e, id) ; end
    def on_message(e, msg)              ; end # optional
    def on_close(e)                     ; end
    def on_shutdown(e)                  ; end
    def on_drained(e)                   ; end
end

class Server::Event
    def sse?                       ; end
    def open?                      ; end
    def close                      ; end
    def write(data)                ; end
    def write_sse(id, event, data) ; end
    def pending                    ; end
end

class SSE::Message
    attr_accessor :id
    attr_accessor :channel
    attr_accessor :message

    def to_s ; message.to_s ; end

    alias :data  :message
    alias :event :channel

end
```

## NeoRack SSE Applications

A NeoRack Applications that supports this extension **SHOULD** responds to the following methods:

* `on_authenticate_sse(e)` - called INSTEAD of the `on_http` method. This method **MUST** return `true` **IF** the connection is allowed to proceed. Any other return value will cause the connection to be refused.

* `on_open(e)` - called when the SSE connection is established.

* `on_eventsource_reconnect(e, id)` - called when a client reconnects. `id` is the last message the client reports as received.

* `on_message(e, msg)` - optional, as servers don't normally receive SSE messages. Called when a message is received. `msg` will be an Object instance that allows the following properties to be fully accessed: `id` (the event ID); `event` (the channel / event); `data` (the SSE payload).

* `on_close(e)` - called when the SSE connection is closed.

* `on_shutdown(e)` - called when the process to which this connection belongs starts shutting down (i.e., during hot restart or server shutdown). NeoRack Servers **MAY** choose to ignore this callback.

* `on_drained(e)` - called when all calls to `e.write` have been handled and the outgoing buffer is now empty. NeoRack Servers **MAY** choose to ignore this callback.

IF `on_authenticate_sse` is missing, Servers **MUST** provide a default implementation that calls `on_authenticate` instead. If `on_authenticate` too is missing, Servers **MUST** provide a default implementation that returns `true` **ONLY IF** the application responds to `on_open`.

### The `on_finish` callback timing

`on_finish` **MUST ALWAYS** be called by NeoRack Servers, or else cleanup may be too difficult to reason about.

When implementing this extension, NeoRack Servers **MUST** call `on_finish` after either a failed client authentication or after calling `on_close`.

Cleanup is at the end.

## The `event` Instance Object (herein `e`)

The following methods MUST be implemented by the `event` instance object:

* `e.sse?` - returns `true` if the connection is an Event Source (SSE) connection.

* `e.open?` - returns `true` if the connection appears to be open and `close` hadn't been called (no known issues).

* `e.close` - schedules the connection to be closed once all calls to `e.write` had finished.

* `e.write(data)` - writes data to the connection or the connection's buffer.

    In general, `data` **SHOULD** be a UTF-8 encoded String.

    If `data` is NOT a String, the server **MAY** attempt to convert it to a JSON String, allowing Hashes, Arrays and other native Ruby objects to be sent over the wire.

    If `data` is an `IO` object the Server **MUST** close it before rejecting it and returning `false`.

    `e.write` **MUST** return `true` if the data was written to the connection or the connection's buffer. `e.write` **SHOULD** return `false` if the data was not written (i.e., the connection is closed and writing is impossible), but **MAY** also throw an exception.

    **Note**: `e.write` is shared between HTTP, WebSocket and SSE connections. Servers **MUST** ensure that the `data` argument is handled correctly based on the connection type.

    **Note**: SSE clients **SHOULD NOT** be able to `write`, as this violates the HTTP protocol. However, abusing the HTTP protocol could be beneficial, so... :) ... the specification doesn't really care.

* `e.write_sse(id, event, data)` - allows the writing of data in SSE specific format.
    
    The `id` and `event` **MUST** be a UTF-8 encoded String (or `nil`). `data` be a UTF-8 encoded String.

    This method **SHOULD** behave the same as `e.write`, only with the addition of `id` and `event` name information passed along to the SSE client according to the Event Source specification.

* `e.pending` - **SHOULD** return the number of bytes that need to be sent before the next `on_drained` callback is called. **MAY** return `true` instead of a number, if the outgoing buffer isn't empty. **Must** return `false` if the outgoing buffer is empty **OR** if the Server never calls `on_drained`.

## The Upgrade Process

When a successful connection upgrade had occurred, the `on_open` callback **MUST** be called before any `on_message` callbacks.

The HTTP `on_finish` callback should **NOT** be called by the Server after a successful upgrade. Instead, the Application **MAY** choose to call `e.handler.on_finish(e)`. This allows the Application to handle the HTTP request as it sees fit.


