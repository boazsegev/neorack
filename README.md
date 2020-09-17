# NeoRack

[Rack](https://github.com/rack/rack) is great and I love all it's done for Ruby. In general it's a great time saver.

However, its design has some shortcomings that we can all sort of mitigate and code around, but cost us developer hours and often leave us with degraded performance.

The NeoRack specification is designed to offer a better solution for Rack's shortcomings by:

* Making polling, streaming and long requests first class citizens.

* Supporting startup-time tests for server features.

* Supporting server extensions that can be implemented by either the server or external gems.

Please read the [NeoRack specifications](SPEC.md) for details.
