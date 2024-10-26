# Cookies Extension

The cookies extension for NeoRack is designed to allow Neo-Rack application to easily access and set cookie data.

This is an extension to the NeoRack specification and is in addition to the core features that **MUST** be implemented according to the NeoRack specification.

## Name and Version

NeoRack Servers supporting this extension **MUST** set this in their `extensions` Hash Map:

```ruby
Server.extensions[:cookies] = [0,0,1]
```

## NeoRack Event Instance

A NeoRack Server `event` instance object (herein `e`) that supports this extension **MUST** responds to the following methods:

* `e.cookie(name)` - returns an ASCII-8 String with the value of the named cookie.

    Cookies that were set using `set_cookie` should be made available if `e.set_cookie` returned `true`.

* `e.set_cookie(name, value = nil, max_age = 0, domain = nil, path = nil, same_site = nil, secure = false, http_only = false, partitioned = false)` - sets the value of the named cookie and returns `true` upon success.

    If `e.headers_sent?` returns `true`, calling this method **SHOULD** return `false` but **MAY** raise an exceptions.
    
    If `value` is `nil`, the cookie will be deleted.

    If `:max_age` is 0 (default), cookie will be session cookie and will be deleted by the browser at its discretion.
    
    This should behave similar to calling `write_header`, except that the cookie **MUST** be accessible when using the `e.cookie` method.

    This method **SHOULD** accept named arguments, if possible. i.e.:

    ```ruby
    set_cookie(name: "MyCookie", value: "My non-secret data", domain: "localhost", max_age: 1_728_000)
    set_cookie("MyCookie", "My non-secret data", domain: "localhost", max_age: 1_728_000)
    ```
    
    For more details, see: [MDN Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie)

* `e.each_cookie(&block)` - calls `block` for each name-value cookie pair received, as well as ones set by a call to `e.set_cookie` that returned `true`.


When implementing this specification, developers **SHOULD** support all the features available for the [`Set-Cookie` header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie), even if not listed here and even if it would require additional arguments to the `set_cookie` method.
