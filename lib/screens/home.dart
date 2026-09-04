// Home tab. Ports the #hero header, the quick-action row, the asset-class
// carousel and the holdings list.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/models.dart';
import '../data/api.dart';
import '../widgets/atoms.dart';
import '../widgets/common.dart';
import '../widgets/hero_header.dart';
import '../widgets/holdings.dart';
import '../widgets/open_security.dart';
import 'transfer.dart';
import 'flows.dart';

/// Ranges and the point counts the web build generates for each.
const Map<String, int> kRanges = {
  '1D': 24,
  '1W': 7,
  '1M': 30,
  '1Y': 12,
  'All': 20,
};

/// Deterministic series, matching series() in index.html — a Lehmer generator
/// seeded at 7 so the shape is identical between runs rather than jittering on
/// every rebuild. Replaced by real history once the API serves it.
List<num> syntheticSeries(int n, num end, double vol, {int seed = 7}) {
  var s = seed;
  double rnd() {
    s = (s * 16807) % 2147483647;
    return s / 2147483647;
  }

  final out = <num>[end];
  for (var i = 1; i < n; i++) {
    out.insert(0, out.first * (1 + (rnd() - 0.52) * vol));
  }
  return out;
}

const List<String> _mon = ['Jan','Feb','Mar','Apr','May','Jun',
                           'Jul','Aug','Sep','Oct','Nov','Dec'];
const List<String> _day = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

String _dmy(DateTime d) => '${d.day} ${_mon[d.month - 1]} ${d.year}';

/// The scrub caption for a point, matching RANGES[range].lbl in the source.
String scrubLabelFor(String range, int i) {
  final today = DateTime.now();
  switch (range) {
    case '1D':
      return '${i.toString().padLeft(2, '0')}:00 \u00B7 ${_dmy(today)}';
    case '1W':
      return '${_day[today.subtract(Duration(days: 6 - i)).weekday % 7]} '
          '${_dmy(today.subtract(Duration(days: 6 - i)))}';
    case '1M':
      return _dmy(today.subtract(Duration(days: 29 - i)));
    case '1Y':
      final d = DateTime(today.year, today.month - (11 - i));
      return '${_mon[d.month - 1]} ${d.year}';
    default:
      final d = DateTime(today.year, today.month - 3 * (19 - i));
      return 'Q${((d.month - 1) ~/ 3) + 1} ${d.year}';
  }
}

const Map<String, double> _vol = {
  '1D': .006,
  '1W': .018,
  '1M': .014,
  '1Y': .05,
  'All': .07,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.money,
    this.logoUrl,
    this.onOpenTab,
    this.api,
    this.onChanged,
  });

  final Session session;
  final Money money;
  final String Function(String ticker)? logoUrl;
  final void Function(String tabId)? onOpenTab;

  /// Present once signed in; lets rows open the detail screen.
  final Api? api;
  final VoidCallback? onChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _range = '1M';
  int? _scrub;
  int _group = 0;
  int _sortField = 0; // 0 = position size, 1 = change, 2 = name
  bool _sortAsc = false;

  Portfolio get _p => widget.session.portfolio;

  List<num> get _series => syntheticSeries(
        kRanges[_range]!,
        _p.total == 0 ? 1 : _p.total,
        _vol[_range]!,
      );

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.p0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _hero(context),
          _quickActions(context),
          const SizedBox(height: 12),
          Hairline(),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'My portfolio',
            actionLabel: 'Show all',
            onAction: () => widget.onOpenTab?.call('portfolio'),
            trailing: _sortButton(context),
          ),
          _carousel(context),
          _holdings(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context) => HeroHeader(
        name: widget.session.user.name,
        greeting: _greeting(),
        money: widget.money,
        series: _series,
        range: _range,
        ranges: kRanges.keys.toList(),
        onRange: (r) => setState(() {
          _range = r;
          _scrub = null;
        }),
        onScrub: (i) => setState(() => _scrub = i),
        scrubIndex: _scrub,
        scrubLabel: _scrub == null ? null : scrubLabelFor(_range, _scrub!),
        unread: widget.session.unread,
        // Cycles EGP -> USD -> EGP on tap, as the source does.
        onCurrency: () {
          widget.money.cycleFavourite();
          setState(() {});
        },
        onSettings: () => widget.onOpenTab?.call('settings'),
        onNotifications: () {
          final api = widget.api;
          if (api == null) return;
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => NotificationsScreen(api: api),
          ));
        },
      );

  /// "Good morning" / "Good afternoon" / "Good evening".
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  // ── quick actions ──────────────────────────────────────────────────────

  /// The five actions in the source, in order.
  static const List<(IconData, String)> _actions = [
    (Ph.plus, 'Add money'),
    (Ph.arrowLineDown, 'Withdraw'),
    (Ph.trendUp, 'Buy'),
    (Ph.arrowsLeftRight, 'Transfer'),
    (Ph.receipt, 'Utilities'),
  ];

  Widget _quickActions(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, label) in _actions)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final api = widget.api;
                  if (label == 'Add money' && api != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MoneyFlowScreen(
                        kind: 'deposit',
                        money: widget.money,
                        api: api,
                        available: _p.balances.available,
                        onDone: widget.onChanged,
                      ),
                    ));
                  } else if (label == 'Withdraw' && api != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MoneyFlowScreen(
                        kind: 'withdraw',
                        money: widget.money,
                        api: api,
                        available: _p.balances.available,
                        onDone: widget.onChanged,
                      ),
                    ));
                  } else if (label == 'Buy' && api != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SearchScreen(
                        api: api,
                        money: widget.money,
                        available: _p.balances.available,
                      ),
                    ));
                  } else if (label == 'Transfer') {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TransferScreen(
                        money: widget.money,
                        api: widget.api!,
                        available: _p.balances.available,
                        onDone: widget.onChanged,
                      ),
                    ));
                  } else if (label == 'Utilities') {
                    widget.onOpenTab?.call('money');
                  }
                },
                child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.tint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, size: 21, color: pal.actDk),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: pal.mute)),
                ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "Position ⇅" — opens a small sort sheet for holdings.
  Widget _sortButton(BuildContext context) {
    final pal = context.pal;
    const fields = ['Position', 'Change', 'Name'];
    return GestureDetector(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: pal.p2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheet) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                  const SizedBox(height: 12),
                  Text('Sort by',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                  const SizedBox(height: 8),
                  for (var i = 0; i < fields.length; i++)
                    RadioListTile(
                      title: Text(fields[i]),
                      value: i,
                      groupValue: _sortField,
                      onChanged: (v) {
                        setState(() {
                          if (_sortField == v) _sortAsc = !_sortAsc;
                          else { _sortField = v!; _sortAsc = false; }
                        });
                        Navigator.of(sheet).pop();
                      },
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(['Position', 'Change', 'Name'][_sortField],
              style: TextStyle(fontSize: 11.5, color: pal.mute)),
          const SizedBox(width: 4),
          Icon(Ph.arrowsDownUp, size: 12, color: pal.mute),
        ],
      ),
    );
  }

  Widget _carousel(BuildContext context) => AssetCarousel(
        portfolio: _p,
        money: widget.money,
        onOpenClass: (group) => _openMyClass(context, group),
        onAdd: () => widget.onOpenTab?.call('discover'),
      );

  /// Opens a bottom sheet showing MY holdings in that asset class.
  void _openMyClass(BuildContext context, String group) {
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
                              sessionState: 'Closed',
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

  Widget _holdings(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: HoldingsAccordion(
          portfolio: _p,
          money: widget.money,
          logoUrl: widget.logoUrl,
          onBrowse: () => widget.onOpenTab?.call('discover'),
          onOpenHolding: (h) {
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
        ),
      );
}
