// The Portfolio tab.
//
// Ported from `[data-scr="portfolio"]` and the pfHero / pfManager / pfAlloc /
// pfClasses / holdList / pfOrders blocks of paintStatic().
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/models.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/holdings.dart';
import '../widgets/treemap.dart';
import '../widgets/open_security.dart';
import '../data/api.dart';
import 'home.dart' show syntheticSeries, scrubLabelFor, kRanges;
import 'instrument_list.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({
    super.key,
    required this.session,
    required this.money,
    this.logoUrl,
    this.orders = const [],
    this.api,
    this.onChanged,
  });

  final Session session;
  final Money money;
  final String Function(String ticker)? logoUrl;
  final List<dynamic> orders;
  final Api? api;
  final VoidCallback? onChanged;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  String _range = '1M';
  int? _scrub;

  Portfolio get _p => widget.session.portfolio;

  num get _total => Portfolio.groupOrder
      .fold<num>(0, (a, g) => a + _p.groupTotal(g));

  List<num> get _series => syntheticSeries(
        kRanges[_range]!,
        _total == 0 ? 1 : _total,
        const {'1D': .006, '1W': .018, '1M': .014, '1Y': .05, 'All': .07}[_range]!,
      );

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.p0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Portfolio',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                  const SizedBox(height: 4),
                  Text('Everything you hold, by asset class',
                      style: TextStyle(fontSize: 11.5, color: pal.mute)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hero(context),
                _manager(context),
                _label(context, 'Allocation'),
                _allocation(context),
                _label(context, 'Asset classes'),
                _classes(context),
                _label(context, 'All holdings'),
                _allHoldings(context),
                _label(context, 'Open orders'),
                _openOrders(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(s,
            style: TextStyle(fontSize: 12, color: context.pal.mute)),
      );

  // ── pfHero ──────────────────────────────────────────────────────────────
  //
  // The same skyline as Home, but at opacity .7 inside a bordered card, with
  // its own gradient from paper 2 down to transparent at 46%.

  Widget _hero(BuildContext context) {
    final pal = context.pal;
    final hero = context.hero;
    final series = _series;
    final shown = _scrub == null ? series.last : series[_scrub!];
    final base = series.first;
    final diff = shown - base;
    final pct = base == 0 ? 0.0 : (diff / base * 100).toDouble();
    final up = diff >= 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.p2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.line),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: .7,
                child: Image.asset('assets/sky/skyPhoto.png',
                    fit: BoxFit.fitWidth),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [pal.p2, pal.p2.withValues(alpha: 0)],
                    stops: const [0.0, 0.46],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Portfolio value (${widget.money.code})',
                        style: TextStyle(fontSize: 11, color: pal.mute)),
                    const SizedBox(height: 6),
                    Text(
                      widget.money.format(shown),
                      style: TextStyle(
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: pal.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // The delta here is a filled pill, not bare text.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (up ? pal.gain : pal.loss).withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(up ? Ph.trendUp : Ph.trendDown,
                              size: 12, color: up ? pal.gain : pal.loss),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.money.format(diff.abs())} '
                            '(${pct.abs().toStringAsFixed(2)}%)',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: up ? pal.gain : pal.loss,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              HeroChart(
                values: series,
                height: 96,
                onScrub: (i) => setState(() => _scrub = i),
              ),
              SizedBox(
                height: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Opacity(
                    opacity: _scrub == null ? 0 : 1,
                    child: Text(
                      _scrub == null ? '\u00A0' : scrubLabelFor(_range, _scrub!),
                      style: TextStyle(fontSize: 11, color: pal.mute),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  children: [
                    for (final r in kRanges.keys) ...[
                      GestureDetector(
                        onTap: () => setState(() {
                          _range = r;
                          _scrub = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: r == _range ? hero.chipOn : hero.chipOff,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Opacity(
                            opacity: r == _range ? 1 : .6,
                            child: Text(r,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: hero.chipTx,
                                  fontWeight: r == _range
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                )),
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
        ],
      ),
    );
  }

  // ── pfManager ───────────────────────────────────────────────────────────

  Widget _manager(BuildContext context) {
    final pal = context.pal;
    const actions = [
      (Ph.videoCamera, 'Video'),
      (Ph.phoneCall, 'Call'),
      (Ph.chatCircle, 'Chat'),
      (Ph.dotsThree, 'More'),
    ];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: pal.ink,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('N',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                        ),
                        // The online dot, ringed in the card colour.
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7FD4C3),
                              shape: BoxShape.circle,
                              border: Border.all(color: pal.ink, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Ph.sealCheckFill,
                                    size: 11, color: Colors.white),
                                const SizedBox(width: 4),
                                const Text('Premium',
                                    style: TextStyle(
                                        fontSize: 10.5, color: Colors.white)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text('Nour is your account manager',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                          const SizedBox(height: 2),
                          Text('Online now \u00B7 replies in minutes',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: .75),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: .12)),
                  ),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              left: i == 0
                                  ? BorderSide.none
                                  : BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: .12)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(actions[i].$1,
                                  size: 19, color: Colors.white),
                              const SizedBox(height: 4),
                              Text(actions[i].$2,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color:
                                        Colors.white.withValues(alpha: .80),
                                  )),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.p1,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: pal.tint, shape: BoxShape.circle),
                child: Icon(Ph.headset, size: 20, color: pal.actDk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Questions about your portfolio?',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: pal.ink,
                        )),
                    Text('Chat or call us — we usually reply in minutes',
                        style: TextStyle(fontSize: 11.5, color: pal.mute)),
                  ],
                ),
              ),
              Icon(Ph.caretRight, size: 13, color: pal.mute),
            ],
          ),
        ),
      ],
    );
  }

  // ── pfAlloc ─────────────────────────────────────────────────────────────

  Widget _allocation(BuildContext context) {
    final pal = context.pal;
    return InnerCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total portfolio value',
                style: TextStyle(fontSize: 11, color: pal.mute)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  widget.money.format(_total),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Text(widget.money.code,
                    style: TextStyle(fontSize: 13, color: pal.mute)),
              ],
            ),
            const SizedBox(height: 8),
            AllocationTreemap(portfolio: _p),
          ],
        ),
      ),
    );
  }

  // ── pfClasses ───────────────────────────────────────────────────────────

  Widget _classes(BuildContext context) {
    final pal = context.pal;
    final groups =
        Portfolio.groupOrder.where((g) => _p.groupTotal(g) > 0).toList();
    if (groups.isEmpty) return const SizedBox.shrink();

    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < groups.length; i++)
            GestureDetector(
              onTap: () => _openClass(context, groups[i]),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    top: i == 0 ? BorderSide.none : BorderSide(color: pal.line),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pal.tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(kGroupIcon[groups[i]] ?? Ph.chartBar,
                          size: 19, color: pal.actDk),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(groups[i],
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: pal.ink,
                              )),
                          Text(
                            _p.inGroup(groups[i]).length == 1
                                ? '1 holding'
                                : '${_p.inGroup(groups[i]).length} holdings',
                            style: TextStyle(fontSize: 11, color: pal.mute),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.money.format(_p.groupTotal(groups[i]),
                              decimals: 2),
                          style: TextStyle(
                            fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: pal.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (_p.groupDelta(groups[i]) != 0)
                        PctTag(
                          delta: _p.groupDelta(groups[i]),
                          up: _p.groupDelta(groups[i]) > 0,
                        )
                      else
                        Text('\u2014',
                            style: TextStyle(fontSize: 11, color: pal.mute)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(Ph.caretRight, size: 13, color: pal.mute),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens a bottom sheet showing MY holdings in that asset class.
  void _openClass(BuildContext context, String group) {
    final pal = context.pal;
    final holdings = _p.inGroup(group);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal.p0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: pal.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('My $group',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600,
                            color: pal.ink,
                          )),
                      const Spacer(),
                      Text(
                        widget.money.format(_p.groupTotal(group), decimals: 2),
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: pal.actDk,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: holdings.isEmpty
                  ? Center(
                      child: Text('No $group in your portfolio.',
                          style: TextStyle(fontSize: 13, color: pal.mute)),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: holdings.length,
                      itemBuilder: (context, i) {
                        final h = holdings[i];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(sheet).pop();
                            if (h.ticker.isEmpty || widget.api == null) return;
                            openSecurity(
                              context,
                              api: widget.api!,
                              money: widget.money,
                              instrument: instrumentFromHolding(h),
                              holding: h,
                              available: _p.balances.available,
                              onChanged: widget.onChanged,
                            );
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: pal.line),
                              ),
                            ),
                            child: Row(
                              children: [
                                Mark(
                                  monogram: h.ticker.isEmpty
                                      ? 'C'
                                      : h.ticker.substring(
                                          0, h.ticker.length.clamp(0, 2)),
                                  colour: tickerColour(h.ticker),
                                  ticker: h.ticker,
                                  size: 40,
                                  logoUrl: widget.logoUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          h.ticker.isEmpty
                                              ? 'Cash balance'
                                              : h.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            color: pal.ink,
                                          )),
                                      Text(
                                        h.ticker.isEmpty
                                            ? 'Available to spend'
                                            : '${h.units} ${h.unitLabel}',
                                        style: TextStyle(
                                            fontSize: 11, color: pal.mute),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      widget.money.format(h.value,
                                          decimals: 2),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: pal.ink,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    if (h.change != 0)
                                      PctTag(delta: h.change, up: h.up),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── holdList ────────────────────────────────────────────────────────────
  //
  // A flat card of every holding, sorted by position size — distinct from
  // Home's accordion, which groups by class.

  Widget _allHoldings(BuildContext context) {
    final pal = context.pal;
    final rows = _p.holdings.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (rows.isEmpty) {
      return EmptyState(
        icon: Ph.cube,
        title: 'Nothing here yet',
        body: 'Buy your first stock, fund or gram of gold.',
        ctaLabel: 'Browse investments',
      );
    }

    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: () {
                if (rows[i].ticker.isEmpty || widget.api == null) return;
                openSecurity(
                  context,
                  api: widget.api!,
                  money: widget.money,
                  instrument: instrumentFromHolding(rows[i]),
                  holding: rows[i],
                  available: _p.balances.available,
                  onChanged: widget.onChanged,
                );
              },
              child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0 ? BorderSide.none : BorderSide(color: pal.line),
                ),
              ),
              child: Row(
                children: [
                  Mark(
                    monogram: monogramOf(rows[i]),
                    colour: tickerColour(rows[i].ticker),
                    ticker: rows[i].ticker,
                    size: 38,
                    logoUrl: widget.logoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: pal.ink,
                            )),
                        Text(
                          rows[i].ticker.isEmpty
                              ? 'Available now'
                              : '${rows[i].ticker} \u00B7 ${rows[i].units} ${rows[i].unitLabel}',
                          style: TextStyle(fontSize: 11, color: pal.mute),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.money.format(rows[i].value, decimals: 2),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: pal.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (rows[i].change != 0)
                        PctTag(delta: rows[i].change, up: rows[i].up),
                    ],
                  ),
                ],
              ),
            ),
            ),
        ],
      ),
    );
  }

  // ── pfOrders ────────────────────────────────────────────────────────────

  Widget _openOrders(BuildContext context) {
    final pal = context.pal;
    final pending = widget.orders
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((o) =>
            o['status'] == 'pending' || o['status'] == 'nav-wait')
        .toList();

    if (pending.isEmpty) {
      return EmptyState(
        icon: Ph.listChecks,
        title: 'No open orders',
        body: 'Orders waiting to execute appear here.',
      );
    }

    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < pending.length; i++)
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
                    monogram:
                        '${pending[i]['ticker'] ?? ''}'.padRight(2).substring(0, 2),
                    colour: tickerColour('${pending[i]['ticker'] ?? ''}'),
                    ticker: '${pending[i]['ticker'] ?? ''}',
                    size: 38,
                    logoUrl: widget.logoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${pending[i]['ticker'] ?? ''}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: pal.ink,
                            )),
                        Text(
                          '${pending[i]['side'] ?? ''} '
                          '${pending[i]['type'] ?? ''}'.trim(),
                          style: TextStyle(fontSize: 11, color: pal.mute),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.money.format(
                            (pending[i]['value'] ?? 0) as num,
                            decimals: 2),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: pal.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Pill(
                        text: 'Pending',
                        tone: Tone.mute(context),
                        icon: Ph.clock,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
