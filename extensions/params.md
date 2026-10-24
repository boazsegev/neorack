# Params Extension

This optional extension adds parsed request parameters to `Server::Event`. It does not include route patterns or path parameters.

The following is the **normative specification**:

```ruby
Server.extensions[:params] = [0, 0, 1]

class Server::Event
  # Parse e.query into the request's mutable params Hash; create it if absent.
  # @return [Hash] the request's params Hash
  # MUST NOT merge the query more than once.
  def query2params; end

  # Parse the supported request body into the same Hash; create it if absent.
  # Does not parse e.query.
  # @return [Hash] the request's params Hash
  # MUST NOT merge the body more than once.
  def body2params; end

  # @return [Hash] the same mutable Hash on every call for this request
  # If no Hash exists, MUST call query2params, then body2params.
  # Otherwise MUST return the existing Hash without parsing another source.
  def params; end
end

# A multipart file part: metadata plus a readable binary stream.
#
# `Server::Event::Upload` names this interface, not a required class: servers
# MAY use any class. Servers SHOULD consider subclassing StringIO (in memory)
# or Tempfile (on disk), in binary mode. Apps SHOULD NOT rely on the class.
#
# Metadata readers MUST return the data the client provided, or nil if it was
# not provided, so the interface also fits other streamed data.
class Server::Event::Upload
  # @return [String, nil] client basename, without / or \ path components
  def filename; end
  # @return [String, nil] declared part media type
  def type; end
  # @return [String, nil] form field name
  def name; end
  # @return [String, nil] raw part headers, excluding the separator blank line
  def headers; end

  # MUST behave like IO#read on a binary-mode IO (as StringIO and Tempfile do).
  # @param length [Integer, nil] nil: read all remaining bytes ("" at EOF);
  #   0: return ""; positive: read up to length bytes (nil at EOF)
  # @param out_string [String, nil] if supplied, receives and is the result
  # @return [String, nil] ASCII-8BIT String, or nil at EOF when length > 0
  # After close, MUST raise IOError.
  def read(length = nil, out_string = nil); end

  # Move to byte zero; return 0. After close, MUST raise IOError.
  def rewind; end

  # Return total byte count as Integer; MUST NOT change read position.
  def size; end

  # Copy all bytes, from byte zero, to path (created or truncated).
  # Servers MAY optimize this if later reads still behave the same.
  # @param path [String] path and filename (created / overwritten)
  # @return [Integer] bytes written. After close, MUST raise IOError.
  def save(path)
    rewind
    IO.copy_stream(self, path)
  end

  # Release the stream; repeated calls MUST be harmless.
  # If garbage-collected while open, the stream SHOULD be released as if
  # closed (e.g. ObjectSpace.define_finalizer; File and Tempfile do this).
  def close; end

  # Return true after close; false while readable.
  def closed?; end

  # Rack compatibility access point (Rack multipart Hash keys).
  def [](key) = rack_view[key]

  # Rack compatibility access point; changes only the compatibility view.
  def []=(key, value)
    rack_view[key] = value
  end

  private def rack_view
    @rack_view ||= {
      tempfile: self,
      head: headers,
      filename: filename,
      type: type,
      name: name
    }
  end
end
```

## Request sources

A server advertising this extension MUST parse the query and both form body formats. JSON support is optional.

| Source | Support |
|--------|---------|
| `e.query` | Required |
| `application/x-www-form-urlencoded` body | Required |
| `multipart/form-data` body | Required |
| `application/json` body | Optional; server MUST document support |
| Other `Content-Type` | Not parsed, unless the server documents support |
| Absent `Content-Type` | Not parsed |

- `query2params` MUST treat a nil or empty query as no parameters.
- `body2params` MUST match media types without regard to case or parameters. It MUST still use the multipart `boundary` parameter when parsing that body.
- If JSON is supported, servers SHOULD also parse `application/<subtype>+json`. Only a JSON object contributes parameters. An empty body or a non-object root contributes none. JSON values keep their Ruby equivalents (`Hash`, `Array`, `String`, numbers, `true`, `false`, `nil`).
- Servers MAY also parse other content types they document, for example `text/json` or `application/x-json` as JSON; the rules above apply. Servers MUST NOT parse a body without a `Content-Type` or infer its type from body content.
- Query and form values MUST be Strings; servers MUST NOT infer numeric or Boolean types.

Use the [URL-encoded parser](https://url.spec.whatwg.org/#urlencoded-parsing) for queries and URL-encoded bodies, and [RFC 7578](https://www.rfc-editor.org/rfc/rfc7578) for multipart bodies. These NeoRack choices supplement those formats:

- A name without `=` has the empty String value; empty `&` segments add no pair.
- A malformed percent escape stays literal. Parser malformation MUST NOT raise. A malformed multipart body MAY retain valid parts parsed before the fault. An invalid JSON object MAY retain complete members parsed before the fault; incomplete members MUST NOT be retained.
- Multipart text fields MUST NOT be URL-decoded. Uploaded file bytes MUST NOT become text fields.

`params` merges the query first, then the body. Explicit calls merge sources in call order. Each source is merged at most once.

## Uploads

- A multipart part with a nonempty `filename` MUST yield an upload object implementing `Server::Event::Upload`.
- A part without `filename` is a text field. A part with an empty `filename` MUST NOT become an upload and MAY be omitted. A file part without a usable field name has no params key and MUST be omitted.
- Apps MUST handle `nil` metadata and MUST NOT trust `filename` or `type`. Other part-header metadata remains available in `headers`.
- The upload MUST be open at byte zero when first returned.
- The server MUST close it and remove temporary storage at request end, even if the app never reads it.
- The app MAY close it sooner. To retain the bytes, it MUST copy them during the request (for example, with `save`).

```ruby
# A multipart file field named avatar, with filename="photo.png".
upload = e.params["avatar"]
upload.filename      # => "photo.png"
upload.read(5)       # => up to five file bytes
upload.rewind        # => 0
upload[:tempfile]    # => upload (Rack-style access)
upload.save("avatar.png") # => byte count; retains the bytes
upload.close
upload.closed?       # => true
upload.read          # raises IOError
```

## Names and Conflicts

- **Paths:** After URL decoding, named brackets and dots in query/form names MUST create nested Hashes. A terminal `[]` MUST append to an Array.
- **Literal names:** Empty names or path segments, nonterminal `[]`, and malformed brackets MUST remain one literal String key. `items[][id]` MUST remain literal; arrays of nested objects are allowed.
- **JSON keys:** MUST remain literal, even when they contain dots or brackets.
- **Key type:** All params Hash keys MUST be Strings.

```ruby
# Each line is one query and its resulting params Hash.
"user[name]=A"    # => { "user" => { "name" => "A" } }
"user.name=A"     # => { "user" => { "name" => "A" } }
"tag[]=a&tag[]=b" # => { "tag" => ["a", "b"] }
"a..b=1"          # => { "a..b" => "1" }
"items[][id]=1"   # => { "items[][id]" => "1" }
"items[id][]=1"   # => { "items" => { "id" => ["1"] } }
```

Merge incoming values in arrival order, use the following rules in order of precedence:

1. **No prior key:** Store the incoming value, even if it is `nil`.
2. **Two Hashes:** Merge their members recursively.
3. **Incoming Hash:** Store existing value in the empty string key of the incoming Hash and store Hash as the new value. If the empty string key already has a value, apply conflict resolution rules.
4. **Existing Hash:** A non Hash value conflicting with an existing hash behaves as if it were assigned to the empty string key of the Hash. Conflict resolution applies to these two values.
5. **Two Arrays:** Concatenate with incoming Array.
6. **Existing Array, incoming non-Array other value:** Append incoming value.
7. **Incoming Array:** Wrap existing non-Array value in Array and then concatenate with incoming Array.
8. **Other conflict:** Make an Array containing the existing value followed by the incoming value. An existing `nil` is a value, not an absent key.

**Note:** An upload MUST merge as an "other" value (not a Hash, not an Array), even though it supports Hash-style `[]` access.

```ruby
# Each line is one query and its resulting params Hash.
"a=1&a=2&a=3"        # => { "a" => ["1", "2", "3"] }
"user=x&user.name=A" # => { "user" => { "" => "x", "name" => "A" } }
"user.name=A&user=x" # => { "user" => { "" => "x", "name" => "A" } }
"tag=x&tag[]=a"      # => { "tag" => ["x", "a"] }
"a=%GG&flag&x=a+b"   # => { "a" => "%GG", "flag" => "", "x" => "a b" }
```

Unlike Rack's last-value-wins rule, repeated scalars remain visible. An Array does not identify whether its values came from duplicates, `[]`, or different sources.

## Lifetime and body access

- **Lazy:** Parse a source only on the first call that needs it. Both parsing methods MUST reuse the same mutable, request-scoped Hash. App changes to the Hash MUST remain visible.
- **Memoized:** Changes to `e.query` or the body after parsing MUST NOT cause automatic reparsing. Servers MUST NOT share parsed state or parameter values across requests.
- **Body position:** `body2params` MUST save `e.seek`, read from the beginning, then restore the saved position, even after malformed input. A later `e.read` MUST see the same unread bytes as before parsing.
- **Body availability:** If `e.close_body` was called, the body contributes nothing and MUST NOT be reopened. Parsing MAY buffer the body but MUST obey the same availability and size limits as `e.read`.

## Security Considerations

**WARNING:** Query strings, forms, upload metadata, and file bytes are untrusted. Applications MUST validate keys and types before using values for access control, SQL, paths, or output. An Array may indicate conflicting values; no source is guaranteed to win.

- **Too many fields:** Servers SHOULD limit query and form fields to 4096 per request by default and SHOULD let users adjust the limit when possible. The count covers every query pair, URL-encoded body pair, and multipart part, including omitted parts (for example, an empty `filename` or a missing field name), across query and body. Exceeding the limit MUST be handled as a resource-limit rejection (see Malformed input) and MUST NOT silently drop fields.
- **Nesting depth:** Servers SHOULD bound the nesting depth of query and form names to 32 levels by default and SHOULD let users adjust the bound when possible. Exceeding the bound MUST be handled as a resource-limit rejection and MUST NOT silently drop the field or keep it as a literal key. Servers SHOULD bound JSON depth and complexity; those limits and their handling are implementation specific and SHOULD be documented.
- **Content types:** Servers MUST NOT parse `text/plain` as JSON; browsers send it cross-origin without a CORS preflight. Types that are not CORS-safelisted, such as `text/json`, are preflighted like `application/json`.
- **Large uploads:** Servers MUST NOT bypass existing request-body limits. Servers SHOULD limit upload count and temporary storage.
- **Malformed input:** Parser malformation MUST NOT raise. Ordinary I/O errors and resource-limit rejection follow the core server's error behavior. Parsers MAY raise `RangeError` or other native Ruby errors for resource-limit rejection.
- **Isolation:** Servers MUST keep parameters and upload storage request-scoped (see Uploads for cleanup).
