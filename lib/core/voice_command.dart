// Voice command parsing — ports normaliseSpeech(), NUMWORDS, AR_DIGITS and
// the INTENTS2 table from index.html.
//
// The order of the intent list matters: specific patterns (buy 50 CLHO) must
// be tried before the loose navigation ones (anything containing "market"),
// so the list is walked top to bottom and the first match wins.
import 'package:flutter/widgets.dart';
import 'ph.dart';

/// Spoken numbers people actually use.
const Map<String, int> kNumWords = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  'eleven': 11, 'twelve': 12, 'fifteen': 15, 'twenty': 20, 'thirty': 30,
  'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80,
  'ninety': 90, 'hundred': 100, 'thousand': 1000,
};

const Map<String, String> kArabicDigits = {
  '\u0660': '0', '\u0661': '1', '\u0662': '2', '\u0663': '3', '\u0664': '4',
  '\u0665': '5', '\u0666': '6', '\u0667': '7', '\u0668': '8', '\u0669': '9',
};

/// What a recogniser hands back is not what a parser wants: digits may be
/// Arabic-Indic, numbers may be words, and people wrap commands in politeness.
String normaliseSpeech(String raw) {
  var s = raw.trim().toLowerCase();

  s = s.split('').map((c) => kArabicDigits[c] ?? c).join();
  s = s.replaceAll(RegExp('[,\u060C]'), '').replaceAll(RegExp(r'\s+'), ' ');

  // "fifty thousand" and "two hundred" before the single words, or "fifty"
  // would be replaced first and the multiplier lost.
  s = s.replaceAllMapped(RegExp(r'\b(\w+)\s+(hundred|thousand)\b'), (m) {
    final n = kNumWords[m[1]];
    final mult = kNumWords[m[2]];
    return (n != null && mult != null) ? '${n * mult}' : m[0]!;
  });
  for (final e in kNumWords.entries) {
    s = s.replaceAll(RegExp('\\b${e.key}\\b'), '${e.value}');
  }

  s = s.replaceAll(
      RegExp(
          r"^(please|can you|could you|i want to|i would like to|i'd like to|let's|lets|hey xflws|xflws)\s+"),
      '');
  s = s.replaceAll(
      RegExp(r'\b(shares?|units?|stocks?|of|the|some|worth of|pounds?|egp|le)\b'),
      ' ');
  s = s.replaceAll(RegExp(r'\bfor me\b|\bnow\b|\bplease\b'), ' ');

  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

enum IntentKind { buy, sell, withdraw, deposit, transfer, alert, ask, nav }

@immutable
class VoiceIntent {
  const VoiceIntent({
    required this.kind,
    required this.say,
    required this.cmd,
    this.auth = 0,
    this.ticker,
    this.quantity,
    this.amount,
    this.to,
    this.route,
    this.normalised = '',
  });

  final IntentKind kind;

  /// The plain-English confirmation shown and spoken back.
  final String say;

  /// The canonical command, echoed into the text field.
  final String cmd;

  /// 0 none, 2 PIN and fingerprint, 3 PIN, fingerprint and face.
  /// Money leaving the account is the only thing that reaches 3.
  final int auth;

  final String? ticker;
  final num? quantity;
  final num? amount;
  final String? to;

  /// Tab or screen id for navigation intents.
  final String? route;

  final String normalised;

  IconData get icon => switch (kind) {
        IntentKind.nav => Ph.arrowRight,
        IntentKind.alert => Ph.bell,
        IntentKind.ask => Ph.sparkle,
        _ => Ph.check,
      };

  String get authLabel => switch (auth) {
        3 => 'Needs PIN, fingerprint and face',
        2 => 'Needs PIN and fingerprint',
        _ => 'No confirmation needed',
      };

  VoiceIntent withNorm(String n) => VoiceIntent(
        kind: kind, say: say, cmd: cmd, auth: auth, ticker: ticker,
        quantity: quantity, amount: amount, to: to, route: route,
        normalised: n,
      );
}

/// Resolves a spoken word to a ticker — either the symbol itself or a
/// recognisable piece of the company name.
String? findTicker(String phrase, List<(String ticker, String name)> universe) {
  final p = phrase.trim().toLowerCase();
  if (p.isEmpty) return null;
  for (final u in universe) {
    if (u.$1.toLowerCase() == p) return u.$1;
  }
  for (final u in universe) {
    final name = u.$2.toLowerCase();
    if (name.contains(p) || p.contains(u.$1.toLowerCase())) return u.$1;
  }
  // Fall back to the first meaningful word, so "cleopatra hospital group"
  // still matches on "cleopatra".
  final first = p.split(' ').first;
  if (first.length >= 3) {
    for (final u in universe) {
      if (u.$2.toLowerCase().contains(first)) return u.$1;
    }
  }
  return null;
}

/// Walks the intent table in order and returns the first match.
VoiceIntent? parseCommand(
  String text,
  List<(String, String)> universe, {
  String currency = 'EGP',
}) {
  final s = normaliseSpeech(text);
  if (s.isEmpty) return null;

  String nameOf(String t) =>
      universe.firstWhere((u) => u.$1 == t, orElse: () => (t, t)).$2;

  // buy / sell
  for (final (re, kind) in [
    (RegExp(r'^(buy|purchase|شراء|اشتري|اشتر|إشتري)\s+([\d.]+)\s+(.+)$'),
        IntentKind.buy),
    (RegExp(r'^(sell|بيع|بع|إبيع)\s+([\d.]+)\s+(.+)$'), IntentKind.sell),
  ]) {
    final m = re.firstMatch(s);
    if (m != null) {
      final t = findTicker(m[3]!, universe);
      if (t != null) {
        final verb = kind == IntentKind.buy ? 'Buy' : 'Sell';
        return VoiceIntent(
          kind: kind,
          ticker: t,
          quantity: num.tryParse(m[2]!),
          say: '$verb ${m[2]} of ${nameOf(t)}',
          cmd: '${verb.toLowerCase()} ${m[2]} $t',
          auth: 2,
        ).withNorm(s);
      }
    }
  }

  var m = RegExp(r'^(withdraw|take out|سحب|اسحب|إسحب)\s+([\d.]+)').firstMatch(s);
  if (m != null) {
    return VoiceIntent(
      kind: IntentKind.withdraw,
      amount: num.tryParse(m[2]!),
      say: 'Withdraw $currency ${m[2]}',
      cmd: 'withdraw ${m[2]}',
      auth: 3,
    ).withNorm(s);
  }

  m = RegExp(r'^(add|deposit|top up|إيداع|اودع|أودع|اضف)\s+([\d.]+)')
      .firstMatch(s);
  if (m != null) {
    return VoiceIntent(
      kind: IntentKind.deposit,
      amount: num.tryParse(m[2]!),
      say: 'Add $currency ${m[2]} to your wallet',
      cmd: 'deposit ${m[2]}',
    ).withNorm(s);
  }

  m = RegExp(r'^(send|transfer|pay|تحويل|حول|ارسل|أرسل)\s+([\d.]+)\s+(?:to|إلى|الى|ل)\s+(.+)$')
      .firstMatch(s);
  if (m != null) {
    return VoiceIntent(
      kind: IntentKind.transfer,
      amount: num.tryParse(m[2]!),
      to: m[3],
      say: 'Send $currency ${m[2]} to ${m[3]}',
      cmd: 'send ${m[2]} to ${m[3]}',
      auth: 3,
    ).withNorm(s);
  }

  m = RegExp(r'alert\s+(?:on\s+|for\s+)?([a-z0-9]{3,8})(?:\s+(?:at|above|below)\s+([\d.]+))?')
      .firstMatch(s);
  if (m != null) {
    final t = findTicker(m[1] ?? '', universe);
    if (t != null) {
      return VoiceIntent(
        kind: IntentKind.alert,
        ticker: t,
        amount: m[2] == null ? null : num.tryParse(m[2]!),
        say: 'Price alert on $t${m[2] != null ? ' at ${m[2]}' : ''}',
        cmd: 'alert $t${m[2] != null ? ' at ${m[2]}' : ''}',
      ).withNorm(s);
    }
  }

  if (RegExp(r'^(how|what|why|when|am i|do i|should i|explain|tell me)\b')
      .hasMatch(s)) {
    return const VoiceIntent(
      kind: IntentKind.ask,
      say: 'Ask the assistant',
      cmd: 'ask the assistant',
    ).withNorm(s);
  }

  for (final (re, route, say) in [
    (RegExp(r'(market|السوق|الأسواق)'), 'markets', 'Open Markets'),
    (RegExp(r'(portfolio|holdings|محفظ)'), 'portfolio', 'Open your portfolio'),
    (RegExp(r'(card|بطاق)'), 'cards', 'Open your cards'),
    (RegExp(r'(gold|ذهب)'), 'portfolio', 'Open Gold'),
    (RegExp(r'(discover|invest)'), 'discover', 'Open Discover'),
    (RegExp(r'(wallet|money|balance)'), 'money', 'Open your wallet'),
    (RegExp(r'(settings|account)'), 'settings', 'Open Settings'),
  ]) {
    if (re.hasMatch(s)) {
      return VoiceIntent(
        kind: IntentKind.nav,
        route: route,
        say: say,
        cmd: 'open $route',
      ).withNorm(s);
    }
  }

  if (RegExp(r'(concentrat|idle cash|fees|dividend|settle)').hasMatch(s)) {
    return const VoiceIntent(
      kind: IntentKind.ask,
      say: 'Ask the assistant',
      cmd: 'ask the assistant',
    ).withNorm(s);
  }

  return null;
}

const List<String> kVoiceExamples = [
  'Buy 50 Cleopatra',
  'Sell 10 CPME',
  'Send 500 to @mona.k',
  'Withdraw 1000',
  'Alert on CLHO at 18.5',
  'Open markets',
  'How is my portfolio doing?',
];
