# Connection Upgrade

The Connection Upgrade Extension describes a connection upgrading API that allows HTTP requests to use a **Callback Object** for other protocols, including WebSockets, EventSource and a raw stream (TCP/IP / tunneling).

Implementations that return a value from the `extensions[:upgrade]` **MUST** conform to this extensions (or one of its versions).

The purpose of this specification is:

1. To improve separation of concerns between servers and applications, making sure all IO / network logic is encapsulated by the NeoRack.

    Simply put, when using this extension, the application / framework doesn’t need to have any knowledge about networking, transport protocols, IO streams, polling, etc'.

1. To make it possible to implement WebSocket / EventSource connections without introducing IO and network concerns to the Application layer.

3. To offer a safe alternative to `hijack`.

## Extension Name

Implementations **MUST** set `extensions[:upgrade]` so it is equal to `[0,1,0].freeze`.

## Raw Data Stream Upgrade

The raw data stream upgrade (tunneled / TCP/IP) forwards incoming data and events to the callback object without any encoding or protocol specific details. It acts as if the connection was a raw TCP/IP connection.

NeoRack implementations that support this mode **MUST** accept the `:raw` (Symbol) in the `response.upgrade` method.

NeoRack implementations that support this mode **MUST** set `classes[:upgrade_raw]` to the class of the object returned by `response.upgrade(Object, :raw)`.

## WebSockets Upgrade

The WebSockets upgrade forwards incoming data and events to the callback object in accordance with the WebSockets protocol.

NeoRack implementations that support this mode **MUST** accept the `:ws` (Symbol) in the `response.upgrade` method.

NeoRack implementations that support this mode **MUST** set `classes[:upgrade_ws]` to the class of the object returned by `response.upgrade(Object, :ws)`.

## EventSource / Server Sent Events (SSE) Upgrade

The EventSource upgrade forwards incoming data and events to the callback object in accordance with the EventSource / Server Sent Events (SSE) protocol.

NeoRack implementations that support this mode **MUST** accept the `:sse` (Symbol) in the `response.upgrade` method.

NeoRack implementations that support the EventSource protocol **MUST** set `classes[:upgrade_sse]` to the class of the object returned by `response.upgrade(Object, :sse)`.

## Evented design vs. non-evented / blocking

This extension is designed to expose an **evented** API to client applications.

However, the evented API **MAY** be implemented by a blocking implementation using non-evented semantics, using blocking `read` and `write` operations.

NeoRack implementations that implement a blocking design **SHOULD** consider that client applications **MAY** call `write` from different threads, which requires `write` to be protected from data fragmentation.

## Concurrency Considerations

Implementations **SHOULD** wait with executing the `request.upgrade` 

## Response Methods

NeoRack implementations that implement this extension **MUST** implement the following methods in the `response` object.

#### `upgrade(callback_object, type = nil)`

**SHOULD** raise an exception if `response.streaming?` would have returned `true`.

**MUST** raise an exception if `response.finished?` would have returned `true`.

**MUST** cause future calls to `response.finished?` to return `true`.

Raises an exception if failed (i.e., `type` is unsupported or can't be used with this HTTP request).

`type` **MUST** be either `nil` or a supported Symbol, such as one of the symbols listed in this specification (`:raw`, `:ws`, `:sse`).

If `type` is `nil`, it **MUST** be automatically calculated by the implementation to best match the requested upgrade type according to the request data. If no best-match is found, implementations **SHOULD** fallback to `:raw`, but **MAY** raise an exception instead.

The `callback_object` is described later on.

#### `upgrade?`

If the HTTP request did not request an upgrade or an EventSource connection, **MUST** return `nil`

Otherwise, returns the best match upgrade type for the HTTP request.

## The Callback Object

Connection upgrade and handling is performed using a Callback Object.

The Callback Object could be a **any** object which implements any (of none) of the following callbacks. The Callback Object **MAY** be a Module, a Class or an instance of either.

All callbacks in the Callback Object accept a `client` object that is described later on.

#### `on_open(client)`

The implementation **MUST** call this method once the connection had been established and/or the Callback Object had been linked to the `client` object.

#### `on_message(client, data)`

The implementation **MUST** call this method when incoming data is received, unless the protocol **SHOULD** ignore any incoming data (i.e., EventSource).

`data` **MUST** be a String with an encoding of UTF-8 for text messages and `binary` encoding for non-text messages (as specified by the implemented Protocol). For raw data connections, `data ` **MUST** always be `binary` encoded.

The *callback object* **MUST** assume that the `data` String will be a **recyclable buffer** and that it's content will be corrupted the moment the `on_message` callback returns.

Implementations **MAY**, optionally, implement a **recyclable buffer** for the `on_message` callback. However, this is optional, is *not* required and might result in issues in cases where the client code is less than pristine.

#### `on_drained(client)`

The implementation **MAY** call this method when the `client.write` buffer becomes empty.

**If** `client.pending` ever returns a non-zero value (see later on), the `on_drained` callback **MUST** be called once the write buffer becomes empty.

#### `on_shutdown(client)`

The implementation **MAY** call this method during the Server's graceful shutdown process, _before_ the connection is closed and in addition to the `on_close` function (which is called _after_ the connection is closed.

**Note**: Applications **MUST** be aware that not all implementations will support this variations, as this may depend on features offered by the server.

#### `on_close(client)`

The implementation **MUST** call this method _after_ the connection was closed for whatever reason (socket errors, parsing errors, timeouts, client disconnection, `client.close` being called, etc') or the Callback Object was replaced by another Callback Object.

#### `on_timeout(client)`

The implementation **MUST** call this method every time the connection times out, allowing the callback object to send a ping.

If no data was sent (or scheduled to be sent) by the time the callback returns, implementations **MUST** close the connections.

## The Client Object

The implementation **MUST** provide the Callback Object with a `client` object, that supports the following methods:

#### `env`

**MUST** return the NeoRack `request` object (the environment in which the connection was "born").

**Note**: the `request` object **MAY** have been altered by the Server or the middleware. Race conditions in this regards **MUST** be avoided, i.e., by delaying the call to `on_open` until the middleware stack unfolded.

#### `write(data)`

Implementations **MUST** schedule **all** the data to be sent and **MAY** send it in a blocking manner.

`data` **MUST** be a String. Implementations **MAY** silently convert non-String objects to JSON if an application attempts to `write` a non-String value, otherwise implementations **SHOULD** throw an exception.

A call to `write` only promises that the data is scheduled to be sent. Implementation details may differ.

`write` shall return `true` on success and `false` if the connection is closed.

For connection protocols that are encoding aware, such as WebSocket:

* If `data` is UTF-8 encoded, the data will be sent as UTF-8 text if supported.

* If `data` is binary encoded it will be sent as non-text binary data (as specified by the protocol).

**Note**: the `write` system calls allows for a partial `write`, whereas this method does not.

#### `ping`

When the connection type / protocol has its own `ping` mechanism, such as the WebSocket protocol's `ping` / `pong` logic, implementations **MUST** send a protocol level `ping`.

**MUST** return `true` if a `ping` was scheduled to be sent or`false` if the connection type / protocol does not support pinging.

#### `close`

Closes the connection.

Returns `nil`.

If `close` is called while there is still data to be sent, implementations **MUST** mark the connection as closed but allow all the data to be sent before actually closing the connection. Implementations for non-blocking Servers **MUST** return immediately even if waiting for data to be sent.

#### `open?`

**MUST** return `false` **if** the connection was never open, is known to be closed or marked to be closed. Otherwise `true` **MUST** be returned.

#### `pending`

`pending` **MUST** return the number of pending writes (messages in the `write` queue\*) that need to be processed before the next time the `on_drained` callback is called.

Implementations **MAY** choose to always return the value `0`.

Implementations that always return `0` **MAY** opt to never call the `on_drained` callback.

Implementations that return a non-zero value **MUST** call the `on_drained` callback when a call to `pending` would return the value `0`.

\* Implementations that divide large messages into a number of smaller messages (implement message fragmentation) **MAY** count each fragment separately, as if the fragmentation was performed by the user and `write` was called more than once per message.

#### `handler`

**MUST** return the callback object linked to the `client` object.

#### `handler=`

**MUST** set a new Callback Object for `client`.

This allows applications to switch from one callback object to another (i.e., in case of credential upgrades).

Once a new Callback Object was set, the implementation **MUST** call the old handler's `on_close` callback and **afterwards** call the new handler's `on_open` callback.

#### `timeout` / `timeout=`

Allows applications to get / set connection timeouts dynamically and separately for each connection.

Implementations **SHOULD** provide a global setting for the default connection timeout or a global setting per supported type of `upgrade`.

It is **RECOMMENDED** (but not required) that a global / default timeout setting be available from the command line (CLI).

#### `type`

**MUST** return the same value that was originally passed along to `response.upgrade(___, type)`.

## Example Usage

The following is an example echo server implemented using this specification:

```ruby
module WSConnection
    def on_open(client)
        puts "WebSocket connection established (#{client.object_id})."
    end
    def on_message(client, data)
        client.write data # echo the data back
        puts "on_drained MUST be implemented if #{ pending } != 0."
    end
    def on_drained(client)
        puts "If this line prints out, on_drained is supported by the server."
    end
    def on_shutdown(client)
        client.write "The server is going away. Goodbye."
    end
    def on_close(client)
        puts "WebSocket connection closed (#{client.object_id})."
    end
    def on_timout(client)
        client.ping || client.write("Does this connection protocol not support pinging...?")
    end
    extend self
end

module App
   def self.call(req, res)
       # accepts all upgrade types except :sse (mostly protocol agnostic)
       if(res.upgrade? && res.upgrade? != :sse)
           return res.upgrade(WSConnection)
       end
       res << "Hello World!"
   end
end

run App
```
