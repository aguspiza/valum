# Response

Response state can be in three distinct states:

 - nothing written
 - status line written
 - headers written

Properties are defined so that the transition between these states can be
monitored.

```javascript
app.get("", (req, res) => {
    res.notify["status-line-written"].connect((s, p) => {
        if (s.status_line_written && s.status == Soup.Status.OK) {
            // status is definitive and 200 OK
        }
    });
    res.notify["headers-written"].connect((s, p) => {
        i (s.headers_written && s.headers.contains("")) {
            // headers are definitive

        }
    });
});
```

## Status

The HTTP status can be assigned using the `Response.status` property.

Constants are defined in libsoup
[Soup.Status](http://valadoc.org/#!api=libsoup-2.4/Soup.Status) enumeration.

## Headers

Headers are provided in `Response`

## Cookies

Response have a simple abstraction to manage cookies sent back to the client
using a `SList<Soup.Cookie>`.

## Body

Response inherit from
[GLib.OutputStream](http://valadoc.org/#!api=gio-2.0/GLib.OutputStream),
providing built-in synchronous and asynchronous stream operations.

```javascript
app.get("", (req, res) => {
    res.splice (req, OutputStreamSpliceFlags.CLOSE_SOURCE);
})
```
