# Pub/Sub Extension

The pub/sub extension for NeoRack is designed to allow Neo-Rack connections to subscribe and publish to an event stream.

This is an extension to the NeoRack specification and is in addition to the core features that **MUST** be implemented according to the NeoRack specification.

```ruby
Server.extensions[:pubsub] = [0,0,1]

Server.instance_eval do
    def subscribe(named_channel, opt = {}, &block) ; end
    def publish(named_channel, message, opt = {})  ; end
end

class Server::Event
    def subscribe(named_channel, opt = {}, &block) ; end
    def publish(named_channel, message, opt = {})  ; end
end

class PubSub::Message
    attr_accessor :id
    attr_accessor :channel
    attr_accessor :message
    attr_accessor :published
    def to_s ; message.to_s ; end
end
```
## Name and Version

NeoRack Servers supporting this extension **MUST** set the correct value in their `extensions` Hash Map, as shown above.

## NeoRack Servers

A NeoRack Server that supports this extension **MUST** responds to the following methods:

* `Server.subscribe(named_channel, opt = {}, &block)` - subscribes to a named channel.

    Named channels **MAY** be binary and **MAY** include the `NUL` character.

    The `block` respond to a `call` method that accepts a pub/sub message object as its only argument.

    Instead of `block`, implementations **MAY** accept a second handler object that responds to a `call` method that accepts the message as the only argument.

    The `opt` Hash **MAY** include implementation-specific options.

* `Server.publish(named_channel, message, opt = {})` - publishes `message` to the named channel. Messages **MAY** be binary and **MAY** include the `NUL` character.

    `Server.publish` **MUST** publish the message to all subscribers.

    **Note**: if the Server has more than a single worker process, the message **MUST** be published to all subscribers on all worker processes.

    The `opt` Hash **MAY** include implementation-specific options.

## NeoRack Event Instance

A NeoRack Server `event` instance object (herein `e`) that supports this extension **MUST** responds to the following methods:

* `e.subscribe(named_channel, opt = {}, &block = nil)` - subscribes to a named channel. See `Server.subscribe` for details.

    `block` is optional. Servers **MUST** provide a default implementation that sends the published message payload as if `e.write` was called with `msg.to_s`.

    The default implementation **SHOULD** send the channel name **ONLY IF** the connection allows this data to be sent as metadata (i.e., SSE events with UTF-8 valid channel names and payloads).

* `e.publish(named_channel, message, opt = {})` - publishes `message` to the named channel. See `Server.subscribe` for publish.

    `e.publish` **SHOULD** publish the message to all subscribers **EXCEPT** the one that published the message.

## Pub/Sub Messages

The pub/sub message object **MUST** respond to the following methods:

* `id` - returns the event's `id` property. This is implementation defined and **MAY** be `nil`.

* `channel` - returns the event's named `channel` property.

* `message` - returns the event's `message` property (the payload).

* `published` - **SHOULD** return the event's timestamp in milliseconds since epoch. This is implementation defined and **MAY** be `nil`.

* `to_s` - (alias to `message`) eturns the event's `message` property (the payload).

The pub/sub message object **MAY** respond to additional, implementation defined, methods.
