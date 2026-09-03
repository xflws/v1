// The Markets tab — all twelve sections of `[data-scr="markets"]`, in order:
// rates, indices, EGX today, breadth, sectors, movers, most active,
// 52-week highs and lows, investor flows, calendar, filings.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/holdings.dart' show tickerColour;
import '../widgets/nav_row.dart';
import '../widgets/open_security.dart';
import 'flows.dart';
import '../data/api.dart';
import '../data/models.dart';

/// RATES — label, level, change, up.
const List<(String, double, double, bool)> kRates = [
  ('USD/EGP', 48.60, 0.12, true),
  ('EUR/EGP', 52.40, -0.21, false),
  ('Gold 24k', 6848.41, 0.28, true),
  ('Brent', 82.30, -0.64, false),
];

/// IDX — name, level, change, up, sparkline series.
const List<(String, String, double, bool, List<num>)> kIndices = [
  ('EGX 30', '53,931.92', -0.10, false,
      [54180, 54090, 54210, 53980, 54050, 53890, 53931]),
  ('EGX 70', '17,706.12', 0.69, true,
      [17580, 17610, 17590, 17650, 17680, 17660, 17706]),
  ('EGX 100', '23,597.48', 0.49, true,
      [23480, 23510, 23495, 23540, 23560, 23575, 23597]),
];

/// SECTORS — name, change, icon.
const List<(String, double, IconData)> kSectors = [
  ('Health care', 2.61, Ph.firstAidKit),
  ('Banks', 1.94, Ph.bank),
  ('Industrials', 0.83, Ph.factory),
  ('Materials', 0.31, Ph.cube),
  ('Real estate', -0.42, Ph.buildings),
  ('Telecom', -1.18, Ph.broadcast),
];

/// MOVERS — ticker, colour, change.
const List<(String, int, double)> kGainers = [
  ('CPME', 0xFF2B2B2B, 18.54), ('AMES', 0xFFB5121B, 12.09),
  ('BIOC', 0xFFF26A2E, 9.93), ('INEG', 0xFF1F6FB2, 9.89),
  ('ACGC', 0xFF2E6B8A, 7.22), ('ELSH', 0xFFD4A017, 7.16),
  ('AFMC', 0xFF7A6A18, 6.43), ('GGCC', 0xFF1E7A4B, 6.33),
];

const List<(String, int, double)> kLosers = [
  ('DSCW', 0xFF111111, -4.82), ('ORWE', 0xFF5B3A8E, -3.91),
  ('SKPC', 0xFF0F6E56, -3.44), ('ETEL', 0xFFA8192A, -3.10),
  ('HRHO', 0xFF1F3A6E, -2.87), ('MFPC', 0xFF8A5A2B, -2.55),
  ('ISPH', 0xFF2E7D6B, -2.31), ('CIEB', 0xFF334155, -2.04),
];

/// ACTIVE — ticker, name, colour, figure.
const List<(String, String, int, double)> kActiveByValue = [
  ('COMI', 'Commercial International Bank', 0xFF1F3A6E, 412.6),
  ('TMGH', 'Talaat Moustafa', 0xFF062E54, 288.1),
  ('ETEL', 'Telecom Egypt', 0xFF5B2D8E, 176.4),
  ('SWDY', 'Elsewedy Electric', 0xFF0E7C5A, 151.9),
  ('ABUK', 'Abu Qir Fertilizers', 0xFF8A5A2B, 134.2),
];

const List<(String, String, int, double)> kActiveByVolume = [
  ('GGCC', 'Giza General Contracting', 0xFF1E7A4B, 18.2),
  ('CCAP', 'Qalaa Holdings', 0xFF062E54, 12.9),
  ('ACGC', 'Arab Cotton Ginning', 0xFF2E6B8A, 12.4),
  ('ETEL', 'Telecom Egypt', 0xFF5B2D8E, 9.8),
  ('CPME', 'Catalyst Partners', 0xFF2B2B2B, 8.4),
];

/// FLOWS — who, net, up.
const List<(String, String, bool)> kFlows = [
  ('Egyptians', '-33.72M', false),
  ('Arabs', '+153.84M', true),
  ('Foreigners', '-120.12M', false),
];

/// NEWS — source, date, headline.
const List<(String, String, String)> kNews = [
  ('EGX', '22 Jul',
      'Juhayna Food Industries (JUFO.CA) declares a stock dividend'),
  ('EGX', '21 Jul',
      'Release from Misr Fertilizers Production Company (MFPC.CA) concerning '
          'the board of directors and executive managers'),
  ('EGX', '21 Jul',
      'Release from Commercial International Bank – Egypt (COMI.CA) regarding '
          'financial results'),
];

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({
    super.key,
    required this.money,
    this.sessionState = 'Closed',
    this.sessionNote = '',
    this.logoUrl,
    this.api,
    this.available = 0,
  });

  final Money money;
  final String sessionState;
  final String sessionNote;
  final String Function(String ticker)? logoUrl;
  final Api? api;

  /// Passed through so a Buy from here can validate against spendable cash.
  final num available;

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  bool _gainers = true;
  bool _byValue = true;
  List<Instrument> _instruments = const [];
  List<dynamic> _liveSectors = const [];
  List<Map<String, dynamic>> _liveIndices = const [];
  Map<String, dynamic> _liveMovers = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Live market data. Each call is independent, so one failing endpoint
  /// leaves the others showing rather than blanking the screen; anything that
  /// does not arrive falls back to the constants below, as the PWA ships.
  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rows = await api.instruments();
      if (mounted) {
        setState(() => _instruments = rows
            .whereType<Map>()
            .map((e) => Instrument.fromJson(Map<String, dynamic>.from(e)))
            .toList());
      }
    } catch (_) {}
    try {
      final m = await api.movers();
      if (mounted) setState(() => _liveMovers = m);
    } catch (_) {}
    try {
      final sc = await api.sectors();
      if (mounted) setState(() => _liveSectors = sc);
    } catch (_) {}
    try {
      final ix = await api.indices();
      if (mounted) {
        setState(() {
          _liveIndices = ix
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Thousands separators for an index level.
  static String _grouped(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final digits = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '$buf.${parts[1]}';
  }

  /// Instruments carry ninety closing prices once seeded; the last few make
  /// the sparkline on an index card.
  List<num> _sparkFor(String ticker, List<num> fallback) {
    for (final i in _instruments) {
      if (i.ticker == ticker && i.history.length > 6) {
        return i.history.sublist(i.history.length - 7);
      }
    }
    return fallback;
  }

  /// (ticker, colour, change) triples, from the API when it answers.
  List<(String, int, double)> get _moverRows {
    final key = _gainers ? 'gainers' : 'losers';
    final rows = _liveMovers[key];
    if (rows is List && rows.isNotEmpty) {
      return rows.whereType<Map>().take(8).map((e) {
        final t = '${e['ticker'] ?? ''}';
        final c = e['change'];
        return (
          t,
          tickerColour(t).toARGB32(),
          (c is num ? c : num.tryParse('$c') ?? 0).toDouble()
        );
      }).toList();
    }
    return _gainers ? kGainers : kLosers;
  }

  /// (name, change, icon) triples.
  List<(String, double, IconData)> get _sectorRows {
    if (_liveSectors.isNotEmpty) {
      return _liveSectors.whereType<Map>().map((e) {
        final name = '${e['sector'] ?? ''}';
        final c = e['change'];
        final icon = kSectors
            .firstWhere((s) => s.$1.toLowerCase() == name.toLowerCase(),
                orElse: () => ('', 0, Ph.cube))
            .$3;
        return (
          name,
          (c is num ? c : num.tryParse('$c') ?? 0).toDouble(),
          icon
        );
      }).toList();
    }
    return kSectors;
  }


  /// Markets rows carry a ticker and a change but no full quote, so the
  /// detail screen is opened with what is known and refreshes itself.
  void _open(String ticker, String name, num change) {
    if (widget.api == null) return;
    openSecurity(
      context,
      api: widget.api!,
      money: widget.money,
      instrument: Instrument(
        ticker: ticker,
        name: name.isEmpty ? ticker : name,
        last: 0,
        change: change,
      ),
      available: widget.available,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.p0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenHeader(
            title: 'Markets',
            subtitle: widget.sessionNote.isEmpty
                ? widget.sessionState
                : '${widget.sessionState} \u00B7 ${widget.sessionNote}',
            trailing: RoundIconButton(
              icon: Ph.magnifyingGlass,
              onTap: widget.api == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SearchScreen(
                          api: widget.api!,
                          money: widget.money,
                          available: widget.available,
                        ),
                      )),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _rates(context),
                const SectionLabel('Indices', top: 20),
                _indices(context),
                const SectionLabel('How the market moved today'),
                _breadth(context),
                const SectionLabel('Sectors'),
                _sectors(context),
                _moversHeader(context),
                _moversGrid(context),
                _activeHeader(context),
                _active(context),
                const SectionLabel('Investor activity, last session'),
                _flows(context),
                const SectionLabel('Latest filings'),
                _news(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── rates ───────────────────────────────────────────────────────────────

  Widget _rates(BuildContext context) {
    final pal = context.pal;
    // The API's indices() route returns both market indices AND the
    // FX/commodity strip. Items with kind != 'index' are rates (USD/EGP,
    // Gold, Brent, etc.).
    final liveRates = _liveIndices
        .where((i) => i['kind'] != 'index')
        .toList();
    final rows = liveRates.isEmpty
        ? kRates.map((r) => (r.$1, r.$2, r.$3, r.$4)).toList()
        : liveRates.map((i) {
            final level = (i['level'] as num?) ?? 0;
            final change = (i['change'] as num?) ?? 0;
            return (
              '${i['name'] ?? i['code']}',
              level.toDouble(),
              change.toDouble(),
              change >= 0,
            );
          }).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final r = rows[i];
          return Container(
            constraints: const BoxConstraints(minWidth: 118),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pal.p2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.$1, style: TextStyle(fontSize: 10.5, color: pal.mute)),
                const SizedBox(height: 2),
                Text(
                  r.$2.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                PctTag(delta: r.$3, up: r.$4),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── indices ─────────────────────────────────────────────────────────────

  Widget _indices(BuildContext context) {
    final pal = context.pal;
    // Only items with kind == 'index' are actual market indices.
    final liveIdx = _liveIndices
        .where((i) => i['kind'] == 'index')
        .toList();
    final rows = liveIdx.isEmpty
        ? kIndices.map((x) => x).toList()
        : liveIdx.map((i) {
            final level = (i['level'] as num?) ?? 0;
            final change = (i['change'] as num?) ?? 0;
            final name = '${i['name'] ?? i['code']}';
            return (
              name,
              _grouped(level.toDouble()),
              change.toDouble(),
              change >= 0,
              // Indices from the API don't carry history; use empty fallback.
              const <num>[],
            );
          }).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final x = rows[i];
          return Container(
            width: 168,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.p2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(x.$1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: pal.ink,
                        )),
                    Icon(Ph.caretRight, size: 11, color: pal.mute),
                  ],
                ),
                const SizedBox(height: 8),
                // Sparkline: live indices don't carry history yet, so show
                // a subtle flat line rather than a misleading random walk.
                if (x.$5.isNotEmpty)
                  Sparkline(
                      values: x.$5,
                      up: x.$4,
                      width: 136,
                      height: 42)
                else
                  SizedBox(width: 136, height: 42),
                const SizedBox(height: 8),
                Text(
                  x.$2,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                PctTag(delta: x.$3, up: x.$4),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── breadth ─────────────────────────────────────────────────────────────

  Widget _breadth(BuildContext context) {
    final pal = context.pal;
    return InnerCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4373,
                      child: ColoredBox(color: pal.loss, child: const SizedBox.expand()),
                    ),
                    Expanded(
                      flex: 1331,
                      child: ColoredBox(
                        color: pal.mute.withValues(alpha: .45),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      flex: 4296,
                      child: ColoredBox(color: pal.gain, child: const SizedBox.expand()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _breadthStat(context, '115', 'losers', pal.loss),
                _breadthStat(context, '35', 'unchanged', pal.ink),
                _breadthStat(context, '113', 'gainers', pal.gain),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _breadthStat(
      BuildContext context, String n, String label, Color colour) {
    final pal = context.pal;
    return Row(
      children: [
        Text(n,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colour,
            )),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: pal.mute)),
      ],
    );
  }

  // ── sectors ─────────────────────────────────────────────────────────────
  //
  // A diverging bar: losses grow leftwards from a centre tick, gains
  // rightwards, each scaled against the largest absolute move.

  Widget _sectors(BuildContext context) {
    final pal = context.pal;
    final sectors = _sectorRows;
    if (sectors.isEmpty) return const SizedBox.shrink();
    final mx = sectors
        .map((s) => s.$2.abs())
        .reduce((a, b) => a > b ? a : b);

    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < sectors.length; i++)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0 ? BorderSide.none : BorderSide(color: pal.line),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.tint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(sectors[i].$3, size: 17, color: pal.actDk),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(sectors[i].$1,
                        style: TextStyle(fontSize: 13.5, color: pal.ink)),
                  ),
                  SizedBox(
                    width: 110,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: sectors[i].$2 >= 0
                                  ? 0
                                  : (sectors[i].$2.abs() / mx),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: pal.loss,
                                  borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(999)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 12, color: pal.line),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: sectors[i].$2 >= 0
                                  ? (sectors[i].$2.abs() / mx)
                                  : 0,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: pal.gain,
                                  borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(999)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${sectors[i].$2 >= 0 ? '+' : ''}'
                      '${sectors[i].$2.toStringAsFixed(2)}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: sectors[i].$2 >= 0 ? pal.gain : pal.loss,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── movers ──────────────────────────────────────────────────────────────

  Widget _moversHeader(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Text('Movers', style: TextStyle(fontSize: 12, color: pal.mute)),
          const Spacer(),
          Text('See all',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: pal.actDk,
              )),
          const SizedBox(width: 12),
          _Segmented(
            options: const ['Gainers', 'Losers'],
            selected: _gainers ? 0 : 1,
            onChanged: (i) => setState(() => _gainers = i == 0),
          ),
        ],
      ),
    );
  }

  Widget _moversGrid(BuildContext context) {
    final pal = context.pal;
    final rows = _moverRows;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: [
        for (final m in rows)
          GestureDetector(
            onTap: () => _open(m.$1, m.$1, m.$3),
            behavior: HitTestBehavior.opaque,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 44px and fully round here, unlike the squarer row tiles.
              ClipOval(
                child: Mark(
                  monogram: m.$1.substring(0, 2),
                  colour: Color(m.$2),
                  ticker: m.$1,
                  size: 44,
                  logoUrl: widget.logoUrl,
                ),
              ),
              const SizedBox(height: 6),
              Text(m.$1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: pal.ink,
                  )),
              PctTag(delta: m.$3, up: m.$3 > 0),
            ],
            ),
          ),
      ],
    );
  }

  // ── most active ─────────────────────────────────────────────────────────

  Widget _activeHeader(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Row(
        children: [
          Text('Most active', style: TextStyle(fontSize: 12, color: pal.mute)),
          const Spacer(),
          _Segmented(
            options: const ['By value', 'By volume'],
            selected: _byValue ? 0 : 1,
            onChanged: (i) => setState(() => _byValue = i == 0),
          ),
        ],
      ),
    );
  }

  Widget _active(BuildContext context) {
    final pal = context.pal;
    // By value ranks on turnover — shares traded times price — and by volume
    // on share count. Ranking by price alone, which an earlier build did, says
    // nothing about how much actually changed hands.
    final live = _instruments.where((i) => i.volume > 0).toList();
    final rows = live.isEmpty
        ? (_byValue ? kActiveByValue : kActiveByVolume)
        : (live
              ..sort((a, b) => _byValue
                  ? b.turnover.compareTo(a.turnover)
                  : b.volume.compareTo(a.volume)))
            .take(5)
            .map((i) => (
                  i.ticker,
                  i.name,
                  tickerColour(i.ticker).toARGB32(),
                  (_byValue ? i.turnover / 1000000 : i.volume / 1000000)
                      .toDouble(),
                ))
            .toList();
    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0 ? BorderSide.none : BorderSide(color: pal.line),
                ),
              ),
              child: Row(
                children: [
                  Mark(
                    monogram: rows[i].$1.substring(0, 2),
                    colour: Color(rows[i].$3),
                    ticker: rows[i].$1,
                    size: 36,
                    logoUrl: widget.logoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: pal.ink,
                            )),
                        Text(rows[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 11, color: pal.mute)),
                      ],
                    ),
                  ),
                  Text(
                    _byValue
                        ? '${rows[i].$4.toStringAsFixed(1)}M'
                        : '${rows[i].$4.toStringAsFixed(1)}M sh',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: pal.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── flows ───────────────────────────────────────────────────────────────

  Widget _flows(BuildContext context) {
    final pal = context.pal;
    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < kFlows.length; i++)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0 ? BorderSide.none : BorderSide(color: pal.line),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(kFlows[i].$1,
                      style: TextStyle(fontSize: 13, color: pal.ink)),
                  Text(
                    kFlows[i].$2,
                    style: TextStyle(
                      fontSize: 13,
                      color: kFlows[i].$3 ? pal.gain : pal.loss,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── filings ─────────────────────────────────────────────────────────────

  Widget _news(BuildContext context) {
    final pal = context.pal;
    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < kNews.length; i++)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0 ? BorderSide.none : BorderSide(color: pal.line),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Pill(text: kNews[i].$1, tone: Tone.ok(context)),
                            const SizedBox(width: 8),
                            Text(kNews[i].$2,
                                style: TextStyle(
                                    fontSize: 11, color: pal.mute)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(kNews[i].$3,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.375,
                              color: pal.ink,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Icon(Ph.caretRight, size: 13, color: pal.mute),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The small pill toggle used for Gainers/Losers and By value/By volume.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: pal.p1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: i == selected ? pal.p2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        i == selected ? FontWeight.w500 : FontWeight.w400,
                    color: i == selected ? pal.ink : pal.mute,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
