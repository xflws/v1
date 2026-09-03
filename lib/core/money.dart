// Ported from the CUR / conv / fmt block in index.html.
//
// The web build carries fixed indicative rates. Those are kept here as the
// offline fallback only — `Money.adopt` replaces them with whatever
// `?r=currencies` returns, which is what should be shown to a customer.
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

@immutable
class Currency {
  const Currency(this.code, this.name, this.rate);

  final String code;
  final String name;

  /// Units of this currency per 1 EGP base. EGP is 1.
  final num rate;
}

class Money extends ChangeNotifier {
  Money();

  /// Indicative rates from the prototype. Replaced on first successful fetch.
  static const Map<String, Currency> _fallback = {
    'EGP': Currency('EGP', 'Egyptian pound', 1),
    'USD': Currency('USD', 'US dollar', 48.6),
    'EUR': Currency('EUR', 'Euro', 52.4),
    'SAR': Currency('SAR', 'Saudi riyal', 12.9),
  };

  /// The two shown beside the flag without opening the picker.
  static const List<String> favourites = ['EGP', 'USD'];

  Map<String, Currency> _rates = Map.of(_fallback);
  String _code = 'EGP';
  bool _live = false;

  String get code => _code;
  Currency get current => _rates[_code] ?? _fallback['EGP']!;
  List<Currency> get all => _rates.values.toList();

  /// False while showing the hard-coded indicative rates. Screens that quote a
  /// converted price should say so when this is false.
  bool get isLive => _live;

  /// Cycle through the favourites, which is what tapping the hero's currency
  /// button does in the source — not open a picker.
  void cycleFavourite() {
    final i = favourites.indexOf(_code);
    _code = i < 0 ? favourites.first : favourites[(i + 1) % favourites.length];
    notifyListeners();
  }

  void select(String code) {
    if (!_rates.containsKey(code) || code == _code) return;
    _code = code;
    notifyListeners();
  }

  /// Takes the `?r=currencies` payload: [{code, name, rate}, ...]
  void adopt(List<dynamic> rows) {
    final next = <String, Currency>{};
    for (final r in rows) {
      final m = Map<String, dynamic>.from(r as Map);
      final code = (m['code'] ?? '').toString();
      if (code.isEmpty) continue;
      next[code] = Currency(
        code,
        (m['name'] ?? code).toString(),
        m['rate'] is num ? m['rate'] as num : num.tryParse('${m['rate']}') ?? 1,
      );
    }
    if (next.isEmpty) return;
    _rates = next;
    _live = true;
    if (!_rates.containsKey(_code)) _code = _rates.keys.first;
    notifyListeners();
  }

  /// EGP amount into the selected currency.
  num convert(num egp) => egp / current.rate;

  /// Grouped, fixed decimals, converted. `fmt()` in the original.
  String format(num egp, {int decimals = 0}) {
    final p = List.filled(decimals, '0').join();
    final pattern = decimals == 0 ? '#,##0' : '#,##0.$p';
    return NumberFormat(pattern, 'en_US').format(convert(egp));
  }

  /// With the currency code appended, e.g. "672,673 EGP".
  String formatWithCode(num egp, {int decimals = 0}) =>
      '${format(egp, decimals: decimals)} $_code';

  /// Signed delta the way the hero shows it: "+4,120 (▲ 0.61%)".
  /// Uses the true minus sign and triangles, as the web build does.
  String formatDelta(num egp, num percent) {
    final up = egp >= 0;
    final sign = up ? '+' : '\u2212';
    final arrow = up ? '\u25B2' : '\u25BC';
    final abs = format(egp.abs(), decimals: 0);
    return '$sign$abs ($arrow ${percent.abs().toStringAsFixed(2)}%)';
  }

  /// "+1.38%" / "−0.51%" for a row.
  static String percent(num p) {
    final sign = p >= 0 ? '+' : '\u2212';
    return '$sign${p.abs().toStringAsFixed(2)}%';
  }
}
