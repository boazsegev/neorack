# NeoRack Specification Rational

This is my understanding so far.

I tried sticking to all the good things the current Rack specification offers, while supporting possible async / streaming / evented implementations.

I would not only love your input, but I would appreciate it if you posted totally different ideas / rational.

Here's some of the things I am trying to accomplish:

### Make Streaming a First Class Citizen - Let CGI play nice with Async

I don't believe that any one concurrency model should be enforced by the specification, especially when such a preference imposes limitations on the things our code can do.

The specification should be implementable in any concurrency model, including linear code or async implementations, supporting streaming applications alongside the classical CGI / Request-response model.

This means that CGI (linear code) must not be a requirement. Web applications should be able to "save" the request somewhere and respond later (i.e., when long polling).

To free developers to choose their own concurrency model, it requires the server to support a finalization method (i.e. `finish`) and possibly a cleanup callback / hook (i.e., `on_finish`).

### Making the Design Modular (allowing for extensions)

This design doesn't include optional features such as `rack.hijack`. All optional features (IMHO) should be specified in extensions rather than the main specification.

I also tried to make it possible to detect Server supported extensions during start up, so it's possible to import external extensions (i.e., a possible future `neorack_websocket` or `neorack_cookie` gem) for missing extensions.

### Avoiding Unnecessary Object Allocations

By using a single `event` object, we avoid unnecessary object allocations where possible.

By not restricting the `event` object implementation to a specific data structure, we allow different implementations to attempt more efficient approaches to the HTTP event data storage – including implementations that directly write to the HTTP transport and implementation that lazily parse header data.

### Abstracting away the Network Layer

I think that Servers shouldn't expose the network layer, at all.

If application developers need raw TCP/IP access, then either the specification is faulty (and should be fixed) or the application is a remote edge case that should be implemented by a development team that can roll their own servers (or, perhaps, the app requirements should be reassessed).

### Abstracting away the HTTP Layer

Although I believe it's impossible to abstract away all the HTTP protocol details, I do believe that we should move as many of the HTTP concerns as possible to the server.

The rest, hopefully, would be abstracted away by frameworks or community gems that will implement HTTP details (such as cookie setting, MIME part parsing, etc').

### MiddleWare Evolves

I don't believe MiddleWare can continue to exist in the same way it existed so far.

The moment we introduce Async / Streaming we allow the app direct access to the output stream, bypassing the MiddleWare's control over the output (unless, of-course, the MiddleWare somehow was allowed to replaces the whole `event` object or network layer).

This prevents the MiddleWare from being able to completely modify the output stream, as the MiddleWare is limited to:

* Validating / updating the event object (pre-App operations), including input parsing, authentication, etc'.

* Assigning resources to the event object (pre-App and post-App operations), including database connection assignments, etc'.

* Diverting the event to a different App / Handler (pre-App / App replacement).

* Handling the the event (pre-App / App replacement).

### Goodbye Logging - All Hail Logging

Logging is important. However, IMHO, it's counterproductive to encourage developers to unify the server and application logging outputs.

In fact, by separating the logging concerns, we are both promoting separation of concerns and (possibly) hinting to developers that server level events could be logged to a different medium than application level and business logic events. This can also minimize the amount of "noise" when following the log output for a specific issue.

### Minimal String Conversions

I understand history has us adding `HTTP_` to the header names and converting `-` into `_`, etc'... but honestly, things would be faster if we used the HTTP headers as is (except, maybe, when making sure they were all lower-case to match HTTP/2 and promote unity).

In addition to the obvious wastefulness of extra memory space and looping over the string to mutate it, adding those extra 5 bytes forces us to choose between separation of concerns (the Rack layer sitting above the HTTP Server) and performance (baking the Rack specification directly into the HTTP parsing stage). This is a waste of both computer and human time and resources and I believe this should be avoided.
