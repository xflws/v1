// The instrument detail screen — `[data-scr="sec"]` and paintSec().
//
// Header with mark, alert and watchlist buttons; a hero card whose chart is
// tinted gain or loss rather than the neutral hero colour; a pill tab strip;
// and a sticky Buy / Sell footer.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/holdings.dart' show tickerColour;
import 'home.dart' show syntheticSeries;

/// The five ranges the detail chart offers — note 5Y here, where the net-worth
/// chart offers All.
const List<String> kSecRanges = ['1D', '1W', '1M', '1Y', '5Y'];
const Map<String, int> _secPoints = {
  '1D': 40,
  '1W': 30,
  '1M': 30,
  '1Y': 24,
  '5Y': 20,
};

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({
    super.key,
    required this.instrument,
    required this.money,
    required this.api,
    this.holding,
    this.logoUrl,
    this.onTrade,
    this.sessionState = 'Closed',
  });

  final Instrument instrument;
  final Money money;
  final Api api;

  /// Present when the customer holds it, which adds the "My position" tab.
  final Holding? holding;
  final String Function(String ticker)? logoUrl;

  /// side is 'buy' or 'sell'.
  final void Function(String side)? onTrade;

  /// Market session state from ?r=meta — unified across the app.
  final String sessionState;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  String _range = '1D';
  String _tab = 'Details';
  int? _scrub;
  bool _fav = false;

  bool get _held => widget.holding != null;
  bool get _isFund => widget.instrument.ticker.startsWith('AZ') ||
      widget.instrument.ticker.startsWith('XF') ||
      widget.instrument.ticker == 'GLD';

  List<String> get _tabs => [
        'Details',
        if (_held) 'My position',
        'Orders',
        if (!_isFund) 'News',
      ];

  Future<void> _saveAlert(
      BuildContext ctx, String direction, num price) async {
    try {
      await widget.api.saveAlert(
        ticker: widget.instrument.ticker,
        direction: direction,
        price: price,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Alert set on ${widget.instrument.ticker} ${direction == 'above' ? '>' : '<'} ${widget.money.format(price, decimals: 2)}',
        ),
      ));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save alert.')),
      );
    }
  }

  void _showAlertDialog(BuildContext ctx) {
    final pal = ctx.pal;
    final priceCtrl = TextEditingController(
      text: widget.instrument.last.toStringAsFixed(2),
    );
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: pal.p2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setS) {
          String direction = 'above';
          String action = 'notify'; // notify | buy | sell
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 16,
                bottom: MediaQuery.of(sheet).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: pal.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Price alert · ${widget.instrument.ticker}',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                  Text(
                    'Last price: ${widget.money.format(widget.instrument.last, decimals: 2)} ${widget.money.code}',
                    style: TextStyle(fontSize: 12, color: pal.mute),
                  ),
                  const SizedBox(height: 16),
                  // Condition: above / below
                  Text('Condition',
                      style: TextStyle(fontSize: 12, color: pal.mute)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (val, label, icon) in [
                        ('above', 'Rises above', Ph.trendUp),
                        ('below', 'Falls below', Ph.trendDown),
                      ])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setS(() => direction = val),
                            child: Container(
                              margin: EdgeInsets.only(
                                  right: val == 'above' ? 6 : 0),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: direction == val
                                    ? pal.tint
                                    : pal.p1,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: direction == val
                                      ? pal.act
                                      : pal.line,
                                  width: direction == val ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, size: 15,
                                      color: direction == val
                                          ? pal.actDk
                                          : pal.mute),
                                  const SizedBox(width: 6),
                                  Text(label,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: direction == val
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: direction == val
                                            ? pal.actDk
                                            : pal.ink,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Price input
                  Text('At price',
                      style: TextStyle(fontSize: 12, color: pal.mute)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      color: pal.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      suffixText: widget.money.code,
                      filled: true,
                      fillColor: pal.p1,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: pal.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: pal.act, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Action: notify / buy / sell
                  Text('When triggered',
                      style: TextStyle(fontSize: 12, color: pal.mute)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final (val, label) in [
                        ('notify', 'Notify me'),
                        ('buy', 'Auto-buy'),
                        ('sell', 'Auto-sell'),
                      ])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setS(() => action = val),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: action == val ? pal.tint : pal.p1,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: action == val
                                      ? pal.act
                                      : pal.line,
                                  width: action == val ? 1.5 : 1,
                                ),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: action == val
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: action == val
                                        ? pal.actDk
                                        : pal.ink,
                                  )),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (action != 'notify') ...[
                    const SizedBox(height: 8),
                    Text(
                      action == 'buy'
                          ? 'Opens a pre-filled buy ticket when the price is reached. You still confirm.'
                          : 'Opens a pre-filled sell ticket when the price is reached. You still confirm.',
                      style: TextStyle(
                          fontSize: 11, height: 1.4, color: pal.mute),
                    ),
                  ],
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () {
                      final px = num.tryParse(priceCtrl.text);
                      if (px == null || px <= 0) return;
                      Navigator.of(sheet).pop();
                      _saveAlert(context, direction, px);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pal.act,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Set alert',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Real closing prices when the backend has them, tailed to the range.
  /// Falls back to the seeded generator so a chart still draws on an
  /// unseeded deployment.
  List<num> get _series {
    final h = widget.instrument.history;
    final want = _secPoints[_range]!;
    if (h.length >= 4) {
      return h.length <= want ? h : h.sublist(h.length - want);
    }
    return syntheticSeries(
      want,
      widget.instrument.last,
      _range == '1D' ? .004 : (_range == '5Y' ? .06 : .02),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(context),
                _hero(context),
                _status(context),
                _tabStrip(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _body(context),
                ),
              ],
            ),
          ),
          _footer(context),
        ],
      ),
    );
  }

  // ── header ──────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    final pal = context.pal;
    final s = widget.instrument;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            _circleButton(context, Ph.caretLeft,
                onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 12),
            Mark(
              monogram: s.ticker.substring(0, s.ticker.length.clamp(0, 2)),
              colour: tickerColour(s.ticker),
              ticker: s.ticker,
              size: 36,
              logoUrl: widget.logoUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.ticker,
                      style: TextStyle(
                          fontSize: 11, height: 1, color: pal.mute)),
                  const SizedBox(height: 4),
                  Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _circleButton(context, Ph.bell),
            const SizedBox(width: 8),
            _circleButton(
              context,
              _fav ? Ph.starFill : Ph.star,
              tint: _fav ? pal.act : null,
              onTap: () => setState(() => _fav = !_fav),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(BuildContext context, IconData icon,
      {VoidCallback? onTap, Color? tint}) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: pal.p1, shape: BoxShape.circle),
        child: Icon(icon, size: 15, color: tint ?? pal.ink),
      ),
    );
  }

  // ── hero ────────────────────────────────────────────────────────────────
  //
  // Unlike the net-worth chart, this one is coloured by direction.

  Widget _hero(BuildContext context) {
    final pal = context.pal;
    final s = widget.instrument;
    final series = _series;
    final shown = _scrub == null ? series.last : series[_scrub!];
    final up = s.change >= 0;
    final colour = up ? pal.gain : pal.loss;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: pal.p2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isFund ? 'NAV per unit' : 'Last trade price',
                      style: TextStyle(fontSize: 11, color: pal.mute)),
                  const SizedBox(height: 6),
                  Text(
                    widget.money.format(shown, decimals: _isFund ? 4 : 2),
                    style: TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: pal.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colour.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(up ? Ph.trendUp : Ph.trendDown,
                            size: 12, color: colour),
                        const SizedBox(width: 6),
                        Text(
                          '${up ? '\u25B2' : '\u25BC'} '
                          '${s.change.abs().toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colour,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Tinted by direction, which is why this is not the shared hero.
            Tokens(
              pal: pal,
              hero: Hero_(
                hbg: pal.p2,
                hfg: pal.ink,
                chart: colour,
                hchip: pal.p1,
                chipOn: pal.tint,
                chipOff: pal.p1,
                chipTx: pal.ink,
              ),
              child: Builder(
                builder: (context) => Column(
                  children: [
                    HeroChart(
                      values: series,
                      height: 110,
                      onScrub: (i) => setState(() => _scrub = i),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: Row(
                        children: [
                          for (final r in kSecRanges) ...[
                            GestureDetector(
                              onTap: () => setState(() {
                                _range = r;
                                _scrub = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: r == _range ? pal.tint : pal.p1,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color:
                                        r == _range ? pal.actDk : pal.mute,
                                    fontWeight: r == _range
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    final pal = context.pal;
    // Use the market-wide session state. If the instrument itself is
    // halted/suspended, show that instead.
    final instState = widget.instrument.state.toLowerCase();
    final isHalted = instState == 'halted' || instState == 'suspended';
    final isOpen = widget.sessionState.toLowerCase().contains('open') ||
        widget.sessionState.toLowerCase() == 'trading';
    final label = isHalted
        ? widget.instrument.state
        : isOpen
            ? 'Trading'
            : 'Market closed';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: (isOpen && !isHalted) ? pal.gain : pal.mute,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 11.5, color: pal.mute)),
        ],
      ),
    );
  }

  Widget _tabStrip(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: pal.p1,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            for (final t in _tabs)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: t == _tab ? pal.p2 : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: t == _tab
                          ? const [
                              BoxShadow(
                                blurRadius: 2,
                                offset: Offset(0, 1),
                                color: Color(0x0F000000),
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      t,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            t == _tab ? FontWeight.w600 : FontWeight.w400,
                        color: t == _tab ? pal.ink : pal.mute,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── body ────────────────────────────────────────────────────────────────

  Widget _body(BuildContext context) => switch (_tab) {
        'My position' => _position(context),
        'Orders' => _ordersTab(context),
        'News' => _newsTab(context),
        _ => _details(context),
      };

  Widget _label(BuildContext context, String s, {double top = 20}) => Padding(
        padding: EdgeInsets.fromLTRB(4, top, 4, 4),
        child: Text(s,
            style: TextStyle(fontSize: 12, color: context.pal.mute)),
      );

  Widget _details(BuildContext context) {
    final pal = context.pal;
    final s = widget.instrument;
    final px = s.last;
    // The source derives the day's band from the last price when the API does
    // not supply one.
    final low = px * 0.985, high = px * 1.015;
    final w52l = px * 0.72, w52h = px * 1.28;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, 'Statistics', top: 16),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    RangeBar(
                        lo: low, hi: high, value: px,
                        label: "Day's range", money: widget.money),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: pal.line)),
                      ),
                      child: RangeBar(
                          lo: w52l, hi: w52h, value: px,
                          label: '52-week range', money: widget.money),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: pal.line)),
                ),
                child: Column(
                  children: [
                    _statRow(context, [
                      ('Open', widget.money.format(px * 0.997, decimals: 2)),
                      ('Previous close',
                          widget.money.format(px * 0.994, decimals: 2)),
                    ]),
                    _statRow(context, [
                      ('Sector', s.sector.isEmpty ? '—' : s.sector),
                      ('State', s.state),
                    ], divided: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        _label(context, 'Price alerts'),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: () => _showAlertDialog(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: pal.act,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Set alert',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      )),
                ),
              ),
              for (final (label, dir, pct) in [
                ('−10%', 'below', 10),
                ('−5%', 'below', 5),
                ('+5%', 'above', 5),
                ('+10%', 'above', 10),
              ]) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _saveAlert(context, dir, px * (1 + (dir == 'above' ? 1 : -1) * pct / 100)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: pal.p1,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(label,
                        style: TextStyle(fontSize: 12.5, color: pal.ink)),
                  ),
                ),
              ],
            ],
          ),
        ),
        _label(context, 'Price depth'),
        DepthBook(price: px, money: widget.money),
      ],
    );
  }

  Widget _statRow(BuildContext context, List<(String, String)> cells,
      {bool divided = false}) {
    final pal = context.pal;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: divided ? BorderSide(color: pal.line) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    left: i == 0
                        ? BorderSide.none
                        : BorderSide(color: pal.line),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cells[i].$1,
                        style: TextStyle(fontSize: 11, color: pal.mute)),
                    const SizedBox(height: 4),
                    Text(cells[i].$2,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: pal.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _position(BuildContext context) {
    final h = widget.holding!;
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, 'My position', top: 16),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _line(context, 'Units', '${h.units} ${h.unitLabel}', true),
              _line(context, 'Market value',
                  widget.money.format(h.value, decimals: 2), false),
              if (h.cost > 0) ...[
                _line(context, 'Book cost',
                    widget.money.format(h.cost, decimals: 2), false),
                _line(
                  context,
                  'Unrealised',
                  widget.money.format(h.unrealised, decimals: 2),
                  false,
                  tone: h.unrealised >= 0 ? pal.gain : pal.loss,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, String k, String v, bool first,
      {Color? tone}) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: pal.line),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontSize: 13, color: pal.mute)),
          Text(v,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tone ?? pal.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }

  Widget _ordersTab(BuildContext context) => EmptyState(
        icon: Ph.listChecks,
        title: 'No orders yet',
        body: 'Orders you place on ${widget.instrument.ticker} appear here.',
      );

  Widget _newsTab(BuildContext context) => EmptyState(
        icon: Ph.fileText,
        title: 'No filings',
        body: 'Company announcements appear here.',
      );

  // ── sticky footer ───────────────────────────────────────────────────────

  Widget _footer(BuildContext context) {
    final pal = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: pal.p2,
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTrade?.call('buy'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.act,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Buy',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        )),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => widget.onTrade?.call('sell'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: pal.line),
                    ),
                    child: Text('Sell',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: pal.ink,
                        )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// rangeBar(lo, hi, v, label) — low and high at the ends, a marker at the
/// current price.
class RangeBar extends StatelessWidget {
  const RangeBar({
    super.key,
    required this.lo,
    required this.hi,
    required this.value,
    required this.label,
    required this.money,
  });

  final num lo;
  final num hi;
  final num value;
  final String label;
  final Money money;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final span = (hi - lo) == 0 ? 1 : (hi - lo);
    final p = ((value - lo) / span).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(money.format(lo, decimals: 2),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              Text(label, style: TextStyle(fontSize: 12, color: pal.mute)),
              Text(money.format(hi, decimals: 2),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: pal.p1,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (c.maxWidth * p - 3).clamp(0.0, c.maxWidth - 6),
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 14,
                      decoration: BoxDecoration(
                        color: pal.act,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// depthBook(t) — five levels either side of the last price, at a tick of
/// 0.1% of price with a one-piastre floor, with volume bars scaled to the
/// largest quantity on either side.
class DepthBook extends StatelessWidget {
  const DepthBook({super.key, required this.price, required this.money});

  final num price;
  final Money money;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final tick = (price * 0.001) < 0.01 ? 0.01 : (price * 0.001);

    final rows = [
      for (var i = 0; i < 5; i++)
        (
          price - tick * (i + 1),
          (4000 / (i + 1) + ((i * 977) % 900)).round(),
          price + tick * (i + 1),
          (3600 / (i + 1) + ((i * 613) % 800)).round(),
        )
    ];
    final mx = rows
        .expand((r) => [r.$2, r.$4])
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Bid volume',
                      style: TextStyle(fontSize: 10.5, color: pal.mute)),
                ),
                SizedBox(
                  width: 110,
                  child: Text('Price',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: pal.mute)),
                ),
                Expanded(
                  child: Text('Ask volume',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 10.5, color: pal.mute)),
                ),
              ],
            ),
          ),
          for (final r in rows)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(r.$2.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            )),
                        const SizedBox(width: 8),
                        Container(
                          width: r.$2 / mx * 54,
                          height: 14,
                          decoration: BoxDecoration(
                            color: pal.gain.withValues(alpha: .28),
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(r.$1.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.gain,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            )),
                        Text(' \u00B7 ',
                            style:
                                TextStyle(fontSize: 12, color: pal.mute)),
                        Text(r.$3.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.loss,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            )),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: r.$4 / mx * 54,
                          height: 14,
                          decoration: BoxDecoration(
                            color: pal.loss.withValues(alpha: .26),
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(r.$4.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
