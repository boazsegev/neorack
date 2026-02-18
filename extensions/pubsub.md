# Pub/Sub Extension

Extends NeoRack to enable publish/subscribe messaging across connections and processes.

## Extension Registration

```ruby
Server.extensions[:pubsub] = [0, 0, 2]
```

## Server Methods

```ruby
module Server
  # Subscribes to a named channel.
  # @param channel [String] channel name; MAY be binary, MAY include NUL
  # @param options [Hash] implementation-specific options (e.g., :since for buffering)
  # @param block [Proc] called with PubSub::Message on each published message
  #   MAY accept handler object with call(msg) instead of block
  def self.subscribe(channel, options = {}, &block); end

  # Unsubscribes a handler from a named channel.
  # @param channel [String] channel name
  # @return [Boolean] true if was unsubscribed and removed, false otherwise
  def self.unsubscribe(channel); end

  # Publishes message to all subscribers on the named channel.
  # @param channel [String] channel name; MAY be binary, MAY include NUL
  # @param message [String] payload; MAY be binary, MAY include NUL
  # @param options [Hash] implementation-specific options
  # MUST publish to all subscribers across ALL worker processes.
  def self.publish(channel, message, options = {}); end
end
```

## Event Methods

```ruby
class Server::Event
  # Subscribes this connection to a named channel.
  # @param channel [String] channel name (see Server.subscribe)
  # @param options [Hash] implementation-specific options
  # @param block [Proc, nil] message handler; if nil, uses default behavior:
  #   Default: calls e.write(msg.to_s) for each message
  #   Default SHOULD include channel name as metadata when connection supports it
  #   (e.g., SSE events with UTF-8 valid channel names)
  def subscribe(channel, options = {}, &block); end

  # Unsubscribes this connection from a named channel.
  # @param channel [String] channel name
  # @return [Boolean] true if was unsubscribed and removed, false otherwise
  def unsubscribe(channel); end

  # Publishes message to named channel.
  # @param channel [String] channel name
  # @param message [String] payload
  # @param options [Hash] implementation-specific options
  # MUST publish to all subscribers EXCEPT the publishing connection.
  def publish(channel, message, options = {}); end
end
```

## Message Object

```ruby
# Message object passed to subscription callbacks.
class PubSub::Message
  attr_accessor :id        # Event ID (implementation-defined, MAY be nil)
  attr_accessor :channel   # Channel name - UTF-8 for text, otherwise binary
  attr_accessor :message   # Payload - UTF-8 for text, otherwise binary
  attr_accessor :published # [Integer, nil] Timestamp in ms since epoch (SHOULD be set, MAY be nil)

  def to_s; message.to_s; end

  # MAY respond to additional implementation-defined methods
end
```
