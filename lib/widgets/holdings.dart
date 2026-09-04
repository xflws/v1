// paintCarousel() and paintLists(), ported.
//
// The carousel is a horizontally scrolling strip of 148px tiles with a dashed
// "Add" tile at the end — not a paged view. The holdings list is a collapsible
// accordion per asset class, with an allocation bar and, when collapsed, a
// stack of overlapping logos standing in for the rows.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/models.dart';
import 'atoms.dart';

/// Stable colour per ticker so a logo-less tile keeps its tint between runs.
Color tickerColour(String ticker) {
  if (ticker.isEmpty) return const Color(0xFF7D8480);
  var hash = 0;
  for (final c in ticker.codeUnits) {
    hash = (hash * 31 + c) & 0x7FFFFFFF;
  }
  const palette = [
    Color(0xFF0FA3A3), Color(0xFF1F3A6E), Color(0xFFB5121B),
    Color(0xFF2B2B2B), Color(0xFF2E6B8A), Color(0xFF1E7A4B),
    Color(0xFF5B3A8E), Color(0xFF1F6FB2), Color(0xFFC17F24),
  ];
  return palette[hash % palette.length];
}

String monogramOf(Holding h) =>
    h.ticker.isEmpty ? 'EG' : h.ticker.substring(0, h.ticker.length.clamp(0, 2));

/// The CLASSES array — seven classes, only those with value are shown.
const List<(String, IconData)> kClasses = [
  ('Stocks', Ph.chartBar),
  ('Funds', Ph.chartPieSlice),
  ('Metal funds', Ph.coins),
  ('Cash', Ph.wallet),
  ('Certificates', Ph.certificate),
  ('Savings plans', Ph.piggyBank),
  ('Margin', Ph.scales),
];

class AssetCarousel extends StatefulWidget {
  const AssetCarousel({
    super.key,
    required this.portfolio,
    required this.money,
    this.onOpenClass,
    this.onAdd,
  });

  final Portfolio portfolio;
  final Money money;
  final ValueChanged<String>? onOpenClass;
  final VoidCallback? onAdd;

  @override
  State<AssetCarousel> createState() => _AssetCarouselState();
}

class _AssetCarouselState extends State<AssetCarousel> {
  final ScrollController _sc = ScrollController();
  int _dot = 0;

  /// The tile pitch: 148px plus the 10px gap.
  static const double _step = 158;

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      final i = (_sc.offset / _step).round();
      if (i != _dot) setState(() => _dot = i);
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final held = kClasses
        .where((c) => widget.portfolio.groupTotal(c.$1) > 0)
        .toList();

    return Column(
      children: [
        SizedBox(
          height: 132,
          child: ListView(
            controller: _sc,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final c in held) ...[
                _ClassTile(
                  label: c.$1,
                  icon: c.$2,
                  value: widget.portfolio.groupTotal(c.$1),
                  delta: widget.portfolio.groupDelta(c.$1),
                  money: widget.money,
                  onTap: () => widget.onOpenClass?.call(c.$1),
                ),
                const SizedBox(width: 10),
              ],
              _AddTile(onTap: widget.onAdd),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // One dot per tile including Add, at .85 / .25 opacity.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < held.length + 1; i++) ...[
              Opacity(
                opacity: i == _dot ? .85 : .25,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: pal.mute, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.delta,
    required this.money,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final num value;
  final num delta;
  final Money money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal.p1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: pal.act),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: pal.mute)),
            const SizedBox(height: 2),
            Text(
              compact(value, money),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: pal.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            if (delta != 0)
              PctTag(delta: delta, up: delta > 0)
            else
              Text('\u2014', style: TextStyle(fontSize: 11, color: pal.mute)),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pal.line, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: pal.tint, shape: BoxShape.circle),
              child: Icon(Ph.plus, size: 22, color: pal.act),
            ),
            const SizedBox(height: 8),
            Text('Add',
                style: TextStyle(fontSize: 12, height: 1.25, color: pal.mute)),
          ],
        ),
      ),
    );
  }
}

// ── the accordion ────────────────────────────────────────────────────────

class HoldingsAccordion extends StatefulWidget {
  const HoldingsAccordion({
    super.key,
    required this.portfolio,
    required this.money,
    this.logoUrl,
    this.onOpenHolding,
    this.onBrowse,
  });

  final Portfolio portfolio;
  final Money money;
  final String Function(String ticker)? logoUrl;
  final ValueChanged<Holding>? onOpenHolding;
  final VoidCallback? onBrowse;

  @override
  State<HoldingsAccordion> createState() => _HoldingsAccordionState();
}

class _HoldingsAccordionState extends State<HoldingsAccordion> {
  /// openG and moreG in the source.
  final Set<String> _open = {};
  final Set<String> _more = {};

  @override
  Widget build(BuildContext context) {
    final total = Portfolio.groupOrder
        .fold<num>(0, (a, g) => a + widget.portfolio.groupTotal(g));

    final groups = Portfolio.groupOrder
        .where((g) => widget.portfolio.inGroup(g).isNotEmpty)
        .toList();

    if (groups.isEmpty) {
      return EmptyState(
        icon: Ph.chartBar,
        title: 'Nothing here yet',
        body: 'Buy your first stock, fund or gram of gold.',
        ctaLabel: 'Browse investments',
        onCta: widget.onBrowse,
      );
    }

    return Column(
      children: [for (final g in groups) _section(context, g, total)],
    );
  }

  Widget _section(BuildContext context, String g, num total) {
    final pal = context.pal;
    final rows = widget.portfolio.inGroup(g)
      ..sort((a, b) => b.value.compareTo(a.value));
    final t = widget.portfolio.groupTotal(g);
    final d = widget.portfolio.groupDelta(g);
    final open = _open.contains(g);
    final all = _more.contains(g);
    final shown = all ? rows : rows.take(2).toList();
    final rest = rows.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header
          GestureDetector(
            onTap: () => setState(
                () => open ? _open.remove(g) : _open.add(g)),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.tint,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(kGroupIcon[g] ?? Ph.chartBar,
                      size: 16, color: pal.actDk),
                ),
                const SizedBox(width: 10),
                Text(g,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: pal.ink,
                    )),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: pal.tint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${rows.length}',
                      style: TextStyle(fontSize: 10.5, color: pal.actDk)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total',
                        style: TextStyle(fontSize: 9.5, color: pal.mute)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.money.format(t, decimals: 2),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: pal.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(widget.money.code,
                            style: TextStyle(fontSize: 10, color: pal.mute)),
                      ],
                    ),
                    if (d != 0)
                      PctTag(delta: d, up: d > 0)
                    else
                      Text('\u2014',
                          style: TextStyle(fontSize: 11, color: pal.mute)),
                  ],
                ),
                const SizedBox(width: 8),
                // The icon font ships caret-up but not caret-down — the web
                // build subsets only the glyphs it embeds. Rotating is what
                // actually renders, rather than a missing-glyph box.
                RotatedBox(
                  quarterTurns: open ? 0 : 2,
                  child: Icon(Ph.caretUp, size: 13, color: pal.mute),
                ),
              ],
            ),
          ),

          // allocation bar
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : (t / total).toDouble(),
                minHeight: 3,
                backgroundColor: pal.p1,
                valueColor: AlwaysStoppedAnimation(pal.act),
              ),
            ),
          ),

          if (open) ...[
            for (final h in shown) _row(context, h),
            if (rest > 0)
              _moreButton(
                context,
                label: 'View $rest more',
                leading: MarkStack(
                  items: [
                    for (final h in rows.skip(3).take(4))
                      (monogramOf(h), tickerColour(h.ticker), h.ticker)
                  ],
                  size: 22,
                  logoUrl: widget.logoUrl,
                ),
                onTap: () => setState(() => _more.add(g)),
              ),
            if (all && rows.length > 2)
              _moreButton(
                context,
                label: 'View less',
                icon: Ph.caretUp,
                onTap: () => setState(() => _more.remove(g)),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: MarkStack(
                  items: [
                    for (final h in rows.take(7))
                      (monogramOf(h), tickerColour(h.ticker), h.ticker)
                  ],
                  logoUrl: widget.logoUrl,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Holding h) {
    final pal = context.pal;
    return GestureDetector(
      onTap: () => widget.onOpenHolding?.call(h),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: pal.line)),
        ),
        child: Row(
          children: [
            Mark(
              monogram: monogramOf(h),
              colour: tickerColour(h.ticker),
              ticker: h.ticker,
              logoUrl: widget.logoUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: pal.ink,
                      )),
                  Text(
                    h.ticker.isEmpty
                        ? 'Available now'
                        : '${h.ticker} \u00B7 ${h.units} ${h.unitLabel}',
                    style: TextStyle(fontSize: 11, color: pal.mute),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.money.format(h.value, decimals: 2),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (h.change != 0) PctTag(delta: h.change, up: h.up),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
    Widget? leading,
    IconData? icon,
  }) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: pal.line)),
        ),
        child: Row(
          mainAxisAlignment:
              leading == null ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 10)],
            if (icon != null) ...[
              Icon(icon, size: 12, color: pal.actDk),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: pal.actDk,
                )),
          ],
        ),
      ),
    );
  }
}
