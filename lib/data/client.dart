// Picks the right http.Client for the platform.
//
// Cookies work differently on web than anywhere else, so the client that
// carries the session differs too. The conditional import below resolves to
// the browser version when compiling for web and the IO version otherwise.
import 'package:http/http.dart' as http;

import 'client_io.dart' if (dart.library.js_interop) 'client_web.dart'
    as impl;

/// A client that carries the PHP session cookie on every request.
http.Client createClient() => impl.createClient();

/// True when the browser owns the cookie jar and Dart cannot see it.
/// On web the `Cookie` header is forbidden to script and `Set-Cookie` is
/// HttpOnly, so the client must not try to manage cookies itself.
bool get browserManagesCookies => impl.browserManagesCookies;
