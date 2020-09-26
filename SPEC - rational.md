# NeoRack Specification

The NeoRack specification is a balancing act between a number of conflicting needs:

1. The need to maintain backwards compatibility.

2. The need for a clear API that helps developers intuit how to leverage NeoRack using idiomatic Ruby.

3. The need to support real-time applications (i.e., long polling and connection upgrades).

4. The need to make servers authorship flexible while allowing for more efficiency (less memory use, less string conversions, etc').

## Why a separate response object?

The most backwards compatible approach would have been to have the `request` object called `env` and require that it respond to `.response`.

This would allow Rack and NeoRack applications to look almost the same `Proc.new {|env|...}`.

However, this would also make `response` available for persistent connections long after the response was sent, which may result in subtle bugs.

In addition, NeoRack opted for **explicit backwards compatibility** rather than an **implicit** one.

This means that applications should be aware that they are using a backwards compatibility layer and CGI style Rack code.

## Why not use Hash directly for the request object?

The `request` object should inherit from Hash, but isn't directly a Hash.

This allows Ruby mix-ins to be utilized for NeoRack extensions (i.e., `request.class.include ...`).

By requiring the `request.server` method, servers are already required to add their own method, making it impractical for them to use the Hash class directly.

## Why not adopt Rack's header naming?

The CGI Rack specification used HTTP variables with the `HTTP_` prefix for some (but not all) variables and with the `-` replaced with `_`.

This is a historical CGI requirement related to the fact that the variables were stored in the processes Unix `env` object before the process was forked and had naming restrictions that allowed these objects to be accessed from any script / language (i.e., `bash` scripts, etc').

However, this approach requires more String objects and CPU processing time.

For applications that do not require backwards compatibility, it makes no sense to copy the HTTP header names to a new String when they can simply use the same String (and down-case it in place).

The use of lower case header names also matches the HTTP/2 protocol behavior and provides opportunities for servers to optimize memory usage where header name objects are concerned.
