Middleware are pluggable route callback that provides a various range of
functionnalities.

Unlike [modules](module.md), middlewares are not designed decouple an
application in smaller pieces, but to provide reusable functionnalities like:

 - authentication
 - static content serving from files and
   [gresource](https://developer.gnome.org/gio/stable/gio-GResource.html)
 - automatic headers (Last-Modified, Date, etc...)
 - much more!

Before coding your own stuff, take a look at what Valum provides already.
