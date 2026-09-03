// Android, iOS, desktop. Dart controls the headers, so the Api class stores
// the session cookie itself and replays it.
import 'package:http/http.dart' as http;

http.Client createClient() => http.Client();

bool get browserManagesCookies => false;
