// Models mapped to the payloads the PHP API returns.
//
// The API distinguishes three balances and the app must not conflate them:
//   ledger    everything that is the customer's
//   held      committed to a pending order or withdrawal
//   available free to spend — the only one a customer screen should show
import 'package:flutter/foundation.dart';

num _n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
String _s(dynamic v) => v?.toString() ?? '';

@immutable
class Balances {
  const Balances({this.ledger = 0, this.held = 0, this.available = 0});

  final num ledger;
  final num held;
  final num available;

  factory Balances.fromJson(Map<String, dynamic> j) => Balances(
        ledger: _n(j['ledger']),
        held: _n(j['held']),
        available: _n(j['available']),
      );
}

@immutable
class Holding {
  const Holding({
    required this.group,
    required this.ticker,
    required this.name,
    required this.units,
    required this.unitLabel,
    required this.price,
    required this.change,
    required this.value,
    this.cost = 0,
  });

  /// Stocks | Funds | Metal funds | Cash — drives the carousel grouping.
  final String group;
  final String ticker;
  final String name;
  final num units;

  /// 'shares', 'units', 'grams'.
  final String unitLabel;
  final num price;

  /// Percentage move today. Negative means down.
  final num change;
  final num value;

  /// What was paid, for the unrealised figure.
  final num cost;

  bool get up => change >= 0;

  /// Unrealised profit against what was paid. Zero when cost is unknown.
  num get unrealised => cost == 0 ? 0 : value - cost;

  /// The two-letter monogram shown when no logo PNG exists.
  String get monogram =>
      ticker.isEmpty ? '··' : ticker.substring(0, ticker.length.clamp(0, 2));

  /// The API returns `kind` (stock | fund | metal | cash) and a `sector`;
  /// the carousel groups by the four display buckets the UI shows. Metal is
  /// its own bucket rather than a fund, because the original separates them.
  static String groupFor(String kind, String sector) {
    switch (kind.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'metal':
      case 'commodity':
        return 'Metal funds';
      case 'fund':
      case 'etf':
        return sector.toLowerCase().contains('metal') ||
                sector.toLowerCase().contains('gold')
            ? 'Metal funds'
            : 'Funds';
      default:
        return 'Stocks';
    }
  }

  factory Holding.fromJson(Map<String, dynamic> j) {
    final kind = _s(j['kind']);
    final sector = _s(j['sector']);
    return Holding(
      group: j['g'] != null
          ? _s(j['g'])
          : Holding.groupFor(kind, sector),
      ticker: _s(j['ticker'] ?? j['t']),
      name: _s(j['name'] ?? j['n']),
      units: _n(j['units'] ?? j['quantity']),
      unitLabel: _s(j['unitLabel']).isNotEmpty
          ? _s(j['unitLabel'])
          : (kind == 'fund' ? 'units' : (kind == 'metal' ? 'grams' : 'shares')),
      // `last` is the live price; `avg` is the average cost, not a price.
      price: _n(j['last'] ?? j['price']),
      change: _n(j['change']),
      value: _n(j['value']),
      cost: _n(j['cost']),
    );
  }
}

@immutable
class Portfolio {
  const Portfolio({
    this.total = 0,
    this.cash = 0,
    this.holdings = const [],
    this.balances = const Balances(),
  });

  final num total;
  final num cash;
  final List<Holding> holdings;
  final Balances balances;

  static const List<String> groupOrder = [
    'Stocks',
    'Funds',
    'Metal funds',
    'Cash',
  ];

  List<Holding> inGroup(String g) =>
      holdings.where((h) => h.group == g).toList();

  num groupTotal(String g) =>
      inGroup(g).fold<num>(0, (a, h) => a + h.value);

  /// Value-weighted move for a group, matching gDelta() in the web build.
  num groupDelta(String g) {
    final rows = inGroup(g);
    final t = groupTotal(g);
    if (t == 0) return 0;
    return rows.fold<num>(0, (a, h) => a + h.value * h.change) / t;
  }

  factory Portfolio.fromJson(Map<String, dynamic> j) {
    final raw = (j['holdings'] as List?) ?? const [];
    final cash = _n(j['cash']);

    final rows = raw
        .map((e) => Holding.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // The API keeps cash out of `holdings` — it is a balance, not a position.
    // The carousel shows it as a fourth bucket, so add it here rather than
    // special-casing every screen that iterates holdings.
    if (cash > 0 && !rows.any((h) => h.group == 'Cash')) {
      rows.add(Holding(
        group: 'Cash',
        ticker: '',
        name: 'Cash balance',
        units: 0,
        unitLabel: '',
        price: 0,
        change: 0,
        value: cash,
      ));
    }

    return Portfolio(
      total: _n(j['total']),
      cash: cash,
      holdings: rows,
      // The API returns these flat on the portfolio, not under `balances`.
      balances: Balances(
        ledger: _n(j['total']),
        held: _n(j['held']),
        available: _n(j['available']),
      ),
    );
  }
}

@immutable
class Instrument {
  const Instrument({
    required this.ticker,
    required this.name,
    required this.last,
    required this.change,
    this.state = 'Trading',
    this.sector = '',
    this.kind = 'share',
    this.currency = 'EGP',
    this.index = '',
    this.listed = '',
    this.history = const [],
    this.volume = 0,
    this.turnover = 0,
  });

  final String ticker;
  final String name;
  final num last;
  final num change;

  /// Trading | Halted | Suspended | Closed.
  final String state;
  final String sector;

  /// share | fund | metal — the asset class.
  final String kind;

  /// EGP | USD | EUR
  final String currency;

  /// EGX30 if the stock is in the index.
  final String index;

  /// Year listed, for "Recently listed" collections.
  final String listed;

  /// Closing prices, oldest first, seeded ninety days deep by the backend.
  /// Empty when the deployment has not been seeded.
  final List<num> history;

  /// Shares traded this session, and their value. Turnover is what "most
  /// active" should rank by — a cheap stock trading heavily beats an
  /// expensive one that barely moves.
  final num volume;
  final num turnover;

  bool get up => change >= 0;
  bool get tradable => state == 'Trading';

  factory Instrument.fromJson(Map<String, dynamic> j) => Instrument(
        ticker: _s(j['ticker']),
        name: _s(j['name']),
        last: _n(j['last']),
        change: _n(j['change']),
        state: _s(j['state']).isEmpty ? 'Trading' : _s(j['state']),
        sector: _s(j['sector']),
        kind: _s(j['kind']).isEmpty ? 'share' : _s(j['kind']),
        currency: _s(j['currency']).isEmpty ? 'EGP' : _s(j['currency']),
        index: _s(j['index']),
        listed: _s(j['listed']),
        history: ((j['history'] as List?) ?? const [])
            .map((e) => e is num ? e : num.tryParse('$e') ?? 0)
            .toList(),
        volume: _n(j['volume']),
        turnover: _n(j['turnover']),
      );
}

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.handle,
    this.email = '',
    this.phone = '',
    this.role = 'customer',
    this.state = 'active',
    this.kycTier = 0,
  });

  final String id;
  final String name;
  final String handle;
  final String email;
  final String phone;
  final String role;
  final String state;
  final int kycTier;

  String get firstName => name.split(' ').first;
  bool get isCustomer => role == 'customer';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: _s(j['id']),
        name: _s(j['name']),
        handle: _s(j['handle']),
        email: _s(j['email']),
        phone: _s(j['phone']),
        role: _s(j['role']).isEmpty ? 'customer' : _s(j['role']),
        state: _s(j['state']).isEmpty ? 'active' : _s(j['state']),
        kycTier: _n(j['kycTier']).toInt(),
      );
}

/// Everything `?r=me` hands back in one object.
@immutable
class Session {
  const Session({
    required this.user,
    required this.portfolio,
    this.unread = 0,
    this.mode = 'live',
  });

  final AppUser user;
  final Portfolio portfolio;
  final int unread;
  final String mode;

  bool get isSandbox => mode == 'sandbox';

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        user: AppUser.fromJson(
            Map<String, dynamic>.from((j['user'] ?? const {}) as Map)),
        portfolio: Portfolio.fromJson(
            Map<String, dynamic>.from((j['portfolio'] ?? const {}) as Map)),
        unread: _n(j['unread']).toInt(),
        mode: _s(j['mode']).isEmpty ? 'live' : _s(j['mode']),
      );
}
