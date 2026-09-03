// Web.
//
// The session cookie is HttpOnly, so script cannot read `Set-Cookie`, and
// `Cookie` is a forbidden header, so script cannot set it either. Storing the
// cookie in Dart therefore does nothing on this platform — the request simply
// goes out without it, and the API answers "sign in first".
//
// `withCredentials` hands the job to the browser, which does have the cookie.
// It requires the server to send both `Access-Control-Allow-Credentials: true`
// and a specific `Access-Control-Allow-Origin` — never `*`. The API does.
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

http.Client createClient() => BrowserClient()..withCredentials = true;

bool get browserManagesCookies => true;
