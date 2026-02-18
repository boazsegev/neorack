# WebSocket Extension

Extends NeoRack to handle WebSocket connections.

## Extension Registration

```ruby
Server.extensions[:ws] = [0, 0, 2]
```

## Application Callbacks

```ruby
# WebSocket application callbacks. Apps SHOULD respond to these methods.
module NeoRackApp
  # Called INSTEAD of on_http for WebSocket upgrade requests.
  # MUST return true to allow connection; any other value refuses.
  # Fallback: if missing, Servers MUST call on_authenticate instead.
  #   If both missing, MUST return true ONLY IF app responds to on_open or on_message.
  def on_authenticate_websocket(e); end

  # Called when WebSocket connection is established.
  # MUST be called before any on_message callbacks.
  def on_open(e); end

  # Called when a message is received.
  # @param msg [String] UTF-8 for text messages, Binary for binary messages
  def on_message(e, msg); end

  # Called when WebSocket connection is closed.
  def on_close(e); end

  # (OPTIONAL) Called when process starts shutting down (hot restart/shutdown).
  # Servers MAY ignore this callback.
  def on_shutdown(e); end

  # (OPTIONAL) Called when outgoing buffer is empty (all writes completed).
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
  # @return [Boolean] true if this is a WebSocket connection
  def websocket?; end

  # @return [Boolean] true if connection appears open and close() not called
  def open?; end

  # Schedules connection close after pending writes complete.
  def close; end

  # Writes data to connection or buffer.
  # @param data [String, IO, Object]
  #   String (UTF-8)  -> sent as text message
  #   String (Binary) -> sent as binary message
  #   IO              -> Server MUST close it; MAY refuse and return false
  #   Other           -> Server MAY convert to JSON
  # @return [Boolean] true if accepted, false if connection closed
  # SHOULD return false (not raise) on failure. MAY raise exception.
  # NOTE: Shared with HTTP/SSE; servers MUST handle based on connection type.
  def write(data); end

  # @return [Integer]
  #   Integer -> bytes pending before next on_drained
  #   1       -> buffer not empty (if count unavailable)
  #   0       -> buffer empty OR server never calls on_drained
  def pending; end
end
```
