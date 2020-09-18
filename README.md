# NeoRack
[![NeoRack logo](neorack_logo.png)](SPEC.md)

[Rack](https://github.com/rack/rack) is great and I love all it's done for Ruby. In general it's a great time saver.

However, Rack's design is showing its age and its CGI model has shortcomings that we can all sort of mitigate and code around, but cost us developer hours and often leave us with degraded performance.

The NeoRack specification is designed to offer a solution for these shortcomings by:

* Making long-polling, streaming and long requests first class citizens.

* Supporting server feature testing during startup (rather than during response execution).

* Supporting server extensions that can be implemented by either the server or external gems.

My hope is that one day NeoRack and Rack could be merged in a way that makes developers happy and advanced web applications easy to author.

Please read the [NeoRack specifications](SPEC.md) for details.

