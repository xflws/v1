// Client for the XFLWS PHP API (api/index.php).
//
// Every route is `?r=<name>`. Auth is a PHP session cookie, so the client keeps
// the Set-Cookie value and returns it on later calls. `X-XFLWS-Mode: sandbox`
// selects the sandbox data directory; absent means live.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';

enum ApiMode { live, sandbox }

/// Thrown for any non-2xx response. [code] is the machine-readable string the
/// API returns alongside the message, e.g. BAD_CREDENTIALS, LOCKED_OUT.
class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.code, this.context});

  final String message;
  final int status;
  final String? code;
  final Map<String, dynamic>? context;

  bool get isAuth => status == 401 || code == 'BAD_CREDENTIALS';
  bool get isLockedOut => code == 'LOCKED_OUT';

  @override
  String toString() => message;
}

class Api {
  Api({required this.baseUrl, http.Client? client, this.mode = ApiMode.live})
      : _http = client ?? createClient();

  /// Root of the deployment, e.g. https://api.xflws.com — no trailing slash.
  final String baseUrl;
  final http.Client _http;
  ApiMode mode;

  String? _cookie;
  bool _signedIn = false;

  bool get signedIn => _signedIn;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString('xflws_cookie');
    _signedIn = prefs.getBool('xflws_signed_in') ?? false;
  }

  Future<void> persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_cookie != null && _cookie!.isNotEmpty) {
      await prefs.setString('xflws_cookie', _cookie!);
    } else {
      await prefs.remove('xflws_cookie');
    }
    await prefs.setBool('xflws_signed_in', _signedIn);
  }

  Uri _uri(String route, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/index.php').replace(queryParameters: {
        'r': route,
        ...?query,
      });

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (mode == ApiMode.sandbox) 'X-XFLWS-Mode': 'sandbox',
        if (!browserManagesCookies && _cookie != null) 'Cookie': _cookie!,
      };

  void _absorbCookie(http.Response r) {
    if (browserManagesCookies) return;
    final raw = r.headers['set-cookie'];
    if (raw != null && raw.isNotEmpty) _cookie = raw.split(';').first;
  }

  dynamic _decode(http.Response r) {
    _absorbCookie(r);
    dynamic body;
    try {
      body = jsonDecode(r.body);
    } catch (_) {
      throw ApiException(
        'The server did not return JSON (HTTP ${r.statusCode}). '
        'Check that the API path is correct.',
        status: r.statusCode,
      );
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    throw ApiException(
      (map['error'] ?? 'Request failed').toString(),
      status: r.statusCode,
      code: map['code'] as String?,
      context: map['context'] as Map<String, dynamic>?,
    );
  }

  Future<dynamic> get(String route, [Map<String, String>? query]) async =>
      _decode(await _http.get(_uri(route, query), headers: _headers));

  Future<dynamic> post(String route, [Map<String, dynamic>? body]) async =>
      _decode(await _http.post(
        _uri(route),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode(body ?? const {}),
      ));

  // ── the routes the customer app actually uses ──────────────────────────

  /// Accepts an email, an @handle, or a phone number in any format.
  Future<Map<String, dynamic>> login(String user, String password) async {
    final r = await post('auth.login', {'user': user, 'password': password});
    _signedIn = true;
    await persistSession();
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> logout() async {
    try {
      await post('auth.logout');
    } finally {
      _cookie = null;
      _signedIn = false;
      await persistSession();
    }
  }

  /// Is the session still alive? Cheap enough to call on resume.
  Future<bool> sessionAlive() async {
    try {
      final r = await get('auth.session');
      return r is Map && r['signedIn'] == true;
    } on ApiException {
      return false;
    }
  }

  /// The signed-in customer plus their whole portfolio and unread count.
  /// This is the app's bootstrap call.
  Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await get('me') as Map);

  /// Several routes wrap their rows in an object rather than returning a bare
  /// array. Pulling the list out here keeps every caller from having to know
  /// which shape a given route uses.
  static List<dynamic> _rows(dynamic body, [String? key]) {
    if (body is List) return body;
    if (body is Map) {
      if (key != null && body[key] is List) return body[key] as List;
      for (final v in body.values) {
        if (v is List) return v;
      }
    }
    return const [];
  }

  Future<List<dynamic>> instruments() async =>
      _rows(await get('market.instruments'), 'instruments');

  /// Trigger Yahoo Finance price update for all instruments.
  Future<int> updatePrices() async {
    final r = await post('market.prices.update');
    return (r is Map && r['updated'] is num) ? (r['updated'] as num).toInt() : 0;
  }

  /// Remove invalid instruments (no real name, placeholder data).
  Future<int> cleanInstruments() async {
    final r = await post('market.instruments.clean');
    return (r is Map && r['removed'] is num) ? (r['removed'] as num).toInt() : 0;
  }

  /// Index levels and the FX/commodity strip, editable in the console.
  Future<List<dynamic>> indices() async =>
      _rows(await get('market.indices'), 'indices');

  Future<Map<String, dynamic>> movers() async =>
      Map<String, dynamic>.from(await get('market.movers') as Map);

  Future<List<dynamic>> sectors() async =>
      _rows(await get('market.sectors'), 'sectors');

  Future<Map<String, dynamic>> returns() async =>
      Map<String, dynamic>.from(await get('returns') as Map);

  Future<List<dynamic>> orders() async => _rows(await get('orders'), 'orders');

  /// The exact fee breakdown the fill will charge. The ticket must show this
  /// rather than computing its own, or the ticket and statement drift apart.
  Future<Map<String, dynamic>> quote({
    required String ticker,
    required String side,
    required num quantity,
    num? limit,
  }) async =>
      Map<String, dynamic>.from(await post('orders.quote', {
        'ticker': ticker,
        'side': side,
        'quantity': quantity,
        if (limit != null) 'limit': limit,
      }) as Map);

  Future<Map<String, dynamic>> placeOrder({
    required String ticker,
    required String side,
    required num quantity,
    num? limit,
  }) async =>
      Map<String, dynamic>.from(await post('orders.place', {
        'ticker': ticker,
        'side': side,
        'quantity': quantity,
        if (limit != null) 'limit': limit,
      }) as Map);

  // ── customer money, scoped to the session ─────────────────────────────

  Future<Map<String, dynamic>> deposit(num amount, String method) async =>
      Map<String, dynamic>.from(
          await post('app.deposit', {'amount': amount, 'method': method}) as Map);

  Future<Map<String, dynamic>> withdraw(num amount, String method) async =>
      Map<String, dynamic>.from(
          await post('app.withdraw', {'amount': amount, 'method': method}) as Map);

  Future<Map<String, dynamic>> payBill({
    required num amount,
    required String biller,
    required String reference,
  }) async =>
      Map<String, dynamic>.from(await post('app.bill', {
        'amount': amount,
        'biller': biller,
        'reference': reference,
      }) as Map);

  Future<Map<String, dynamic>> transfer({
    required num amount,
    required String to,
    String note = '',
  }) async =>
      Map<String, dynamic>.from(await post('app.transfer', {
        'amount': amount,
        'to': to,
        'note': note,
      }) as Map);

  Future<List<dynamic>> transactions() async =>
      _rows(await get('app.transactions'), 'transactions');

  Future<List<dynamic>> alerts() async => _rows(await get('app.alerts'), 'alerts');

  Future<void> saveAlert({
    required String ticker,
    required String direction,
    required num price,
    String note = '',
  }) =>
      post('app.alerts.save', {
        'ticker': ticker,
        'direction': direction,
        'price': price,
        'note': note,
      });

  Future<void> deleteAlert(String id) => post('app.alerts.delete', {'id': id});

  Future<Map<String, dynamic>> submitKyc({
    required String accountType,
    required String documentType,
    required String riskProfile,
  }) async =>
      Map<String, dynamic>.from(await post('app.kyc.submit', {
        'accountType': accountType,
        'documentType': documentType,
        'riskProfile': riskProfile,
      }) as Map);

  Future<List<dynamic>> myCards() async => _rows(await get('app.cards'), 'cards');

  Future<void> setCardControl(String id, String control, bool value) =>
      post('app.cards.control',
          {'id': id, 'control': control, 'value': value});

  Future<Map<String, dynamic>> issueCard(String kind) async =>
      Map<String, dynamic>.from(
          await post('app.cards.issue', {'kind': kind}) as Map);

  /// Customer-scoped; `notifications` is the staff-wide route.
  Future<List<dynamic>> myNotifications() async =>
      _rows(await get('app.notifications'), 'notifications');

  Future<void> markNotificationsRead([String? id]) =>
      post('app.notifications.read', {if (id != null) 'id': id});

  Future<List<dynamic>> notifications() async =>
      _rows(await get('notifications'), 'notifications');

  Future<List<dynamic>> cards() async => _rows(await get('cards'), 'cards');

  /// `?r=currencies` answers with a map keyed by code —
  /// {"EGP": {"label": ..., "rate": 1.0, "base": true}, ...} — wrapped in an
  /// envelope alongside `base` and `conventions`. Flattened here into the rows
  /// Money.adopt expects, with `label` mapped onto `name`.
  Future<List<dynamic>> currencies() async {
    final body = await get('currencies');
    final map = body is Map && body['currencies'] is Map
        ? Map<String, dynamic>.from(body['currencies'] as Map)
        : (body is Map ? Map<String, dynamic>.from(body) : const {});
    final out = <Map<String, dynamic>>[];
    map.forEach((code, v) {
      if (v is! Map) return;
      final m = Map<String, dynamic>.from(v);
      out.add({
        'code': code,
        'name': m['label'] ?? m['name'] ?? code,
        'rate': m['rate'] ?? 1,
      });
    });
    return out;
  }

  /// Feature flags and app-side configuration, resolved for this user.
  Future<Map<String, dynamic>> appConfig() async =>
      Map<String, dynamic>.from(await get('app.config') as Map);

  /// Instrument logo, served as PNG straight from the API.
  String logoUrl(String ticker) =>
      '$baseUrl/api/index.php?r=asset.logo&ticker=$ticker';

  void close() => _http.close();
}
