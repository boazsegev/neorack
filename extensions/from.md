# From Extension

The from extension for NeoRack is designed to allow NeoRack application to easily discover the source address from which the request claims to have been sent.

This is an extension to the NeoRack specification and is in addition to the core features that **MUST** be implemented according to the NeoRack specification.

```ruby
Server.extensions[:from] = [0,0,1]

class Server::Event
    def from ; end
end
```

## Name and Version

NeoRack Servers supporting this extension **MUST** set the correct value in their `extensions` Hash Map, as shown above.

## NeoRack Event Instance

A NeoRack Server `event` instance object (herein `e`) that supports this extension **MUST** responds to the following methods:

* `e.from()` - returns a String with the value of the address from which the request claims to have been sent.

    Servers **SHOULD** return the value of the `for` property in the `forwarded` header.

    If the `forwarded` header is missing, Servers **SHOULD** return the first address in the `x-forwarded-for` header.

    If the `forwarded` and the `x-forwarded-for` headers are both missing, Servers **SHOULD** return the return value of `e.peer_addr`.
