# Server-Sent Events (SSE) Extension

Extends NeoRack to handle SSE (EventSource) connections.

## Extension Registration

```ruby
Server.extensions[:sse] = [0, 0, 2]
```

## Application Callbacks

```ruby
# SSE application callbacks. Apps SHOULD respond to these methods.
module NeoRackApp
  # Called INSTEAD of on_http for SSE requests.
  # MUST return true to allow connection; any other value refuses.
  # Fallback: if missing, Servers MUST call on_authenticate instead.
  #   If both missing, MUST return true ONLY IF app responds to on_open.
  def on_authenticate_sse(e); end

  # Called when SSE connection is established (new connection).
  # MUST be called before any on_message callbacks.
  # NOTE: Mutually exclusive with on_eventsource_reconnect - only ONE is called.
  def on_open(e); end

  # Called INSTEAD of on_open when client reconnects with Last-Event-ID header.
  # @param id [String] last message ID the client received
  # NOTE: Mutually exclusive with on_open - only ONE is called per connection.
  def on_eventsource_reconnect(e, id); end

  # (OPTIONAL) Called when message received from client.
  # NOTE: SSE clients normally don't send messages (violates HTTP protocol).
  # @param msg [SSE::Message] object with id, event, data properties
  def on_message(e, msg); end

  # Called when SSE connection is closed.
  def on_close(e); end

  # (OPTIONAL) Called when process starts shutting down.
  # Servers MAY ignore this callback.
  def on_shutdown(e); end

  # (OPTIONAL) Called when outgoing buffer is empty.
  # Servers MAY ignore this callback.
  def on_drained(e); end
end
```

### on_finish Timing

| Rule | Requirement |
|------|-------------|
| Guaranteed call | Servers MUST ALWAYS call on_finish |
| After auth failure | MUST call on_finish after failed authentication |
| After close | MUST call on_finish after on_close |
| After upgrade | SHOULD NOT call on_finish immediately after successful upgrade |

## Event Methods

```ruby
class Server::Event
  # @return [Boolean] true if this is an SSE connection
  def sse?; end

  # @return [Boolean] true if connection appears open and close() not called
  def open?; end

  # Schedules connection close after pending writes complete.
  def close; end

  # Writes raw data to connection.
  # @param data [String, IO, Object]
  #   String -> SHOULD be UTF-8 encoded
  #   IO     -> Server MUST close it, then return false (SSE rejects IO)
  #   Other  -> Server MAY convert to JSON
  # @return [Boolean] true if accepted, false if connection closed
  # SHOULD return false (not raise) on failure. MAY raise exception.
  # NOTE: Shared with HTTP/WebSocket; servers MUST handle based on connection type.
  def write(data); end

  # Writes SSE-formatted event to connection.
  # @param data [String] event payload (UTF-8) - required
  # @param id [String, nil] event ID (UTF-8); nil to omit
  # @param event [String, nil] event type/channel (UTF-8); nil to omit
  # @return [Boolean] same semantics as write()
  # Formats data per EventSource spec (id:, event:, data: fields).
  def write_sse(data, id: nil, event: nil); end

  # @return [Integer, Boolean]
  #   Integer -> bytes pending before next on_drained
  #   true    -> buffer not empty (if count unavailable)
  #   false   -> buffer empty OR server never calls on_drained
  def pending; end
end
```

## SSE Message Object

```ruby
# Message object passed to on_message callback.
class SSE::Message
  attr_accessor :id       # Event ID
  attr_accessor :channel  # Event type (alias: event)
  attr_accessor :message  # Payload (alias: data)

  def to_s; message.to_s; end

  alias data message
  alias event channel
end
```
