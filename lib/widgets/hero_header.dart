// The #hero header, ported element for element from index.html.
//
// Stacking order, matching the z-index in the source:
//   z-0  the Cairo skyline photograph, pinned to the bottom edge
//   z-1  a gradient from --hbg down to transparent at 42%
//   z-2  the faint XFLWS mark, bottom-end corner
//   z-10 the brand bar, avatar row, figures, chart and ranges
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import 'chart.dart';

class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.name,
    required this.greeting,
    required this.money,
    required this.series,
    required this.range,
    required this.ranges,
    required this.onRange,
    required this.onScrub,
    required this.scrubIndex,
    required this.scrubLabel,
    required this.onCurrency,
    required this.onSettings,
    required this.onNotifications,
    this.unread = 0,
  });

  final String name;
  final String greeting;
  final Money money;
  final List<num> series;
  final String range;
  final List<String> ranges;
  final ValueChanged<String> onRange;
  final ValueChanged<int?> onScrub;
  final int? scrubIndex;
  final String? scrubLabel;
  final VoidCallback onCurrency;
  final VoidCallback onSettings;
  final VoidCallback onNotifications;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final hero = context.hero;

    final shown = scrubIndex == null ? series.last : series[scrubIndex!];
    final base = series.first;
    final diff = shown - base;
    final pct = base == 0 ? 0 : diff / base * 100;

    return Container(
      decoration: BoxDecoration(
        color: hero.hbg,
        border: Border(bottom: BorderSide(color: pal.line, width: 0.5)),
      ),
      child: Stack(
        children: [
          // z-0 — the skyline sits on the bottom edge, full width, and is
          // never interactive. Opacity .55 with the white hero, per applyPal().
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55,
                child: Image.asset(
                  'assets/sky/skyPhoto.png',
                  fit: BoxFit.fitWidth,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),

          // z-1 — fades the hero colour down over the top 42%, so the figures
          // stay legible against the photograph.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [hero.hbg, hero.hbg.withValues(alpha: 0)],
                    stops: const [0.0, 0.42],
                  ),
                ),
              ),
            ),
          ),

          // z-10 — everything readable.
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: SvgPicture.asset(
                    'assets/brand/wordmark.svg',
                    height: 20,
                  ),
                ),
                _identityRow(context),
                _figures(context, shown, diff, pct.toDouble()),
                const SizedBox(height: 8),
                HeroChart(
                  values: series,
                  onScrub: onScrub,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Row(
                    children: [
                      for (final r in ranges) ...[
                        _RangeChip(
                          label: r,
                          selected: r == range,
                          onTap: () => onRange(r),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── avatar, greeting, bell, currency ────────────────────────────────────

  Widget _identityRow(BuildContext context) {
    final hero = context.hero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          _Avatar(onTap: onSettings),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(greeting,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      color: hero.hfg.withValues(alpha: .65),
                    )),
                const SizedBox(height: 4),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: hero.hfg,
                    )),
              ],
            ),
          ),
          _BellButton(unread: unread, onTap: onNotifications),
          const SizedBox(width: 8),
          _CurrencyButton(money: money, onTap: onCurrency),
        ],
      ),
    );
  }

  // ── net worth, delta, scrub date ────────────────────────────────────────

  Widget _figures(BuildContext context, num shown, num diff, double pct) {
    final pal = context.pal;
    final hero = context.hero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Net worth (${money.code})',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hero.hfg.withValues(alpha: .65),
                  )),
              const SizedBox(width: 6),
              Icon(Ph.info, size: 12, color: hero.hfg.withValues(alpha: .65)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            money.format(shown),
            style: TextStyle(
              fontSize: 42,
              height: 1,
              fontWeight: FontWeight.w700,
              color: hero.hfg,
              fontFeatures: const [FontFeature.tabularFigures()],
              shadows: const [
                Shadow(blurRadius: 1, offset: Offset(0, 1), color: Color(0x0D000000)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            money.formatDelta(diff, pct),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: diff >= 0 ? pal.gain : pal.loss,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          // Reserves its line whether or not a date is showing, so the chart
          // does not jump as the finger moves.
          SizedBox(
            height: 16,
            child: Opacity(
              opacity: scrubLabel == null ? 0 : 1,
              child: Text(scrubLabel ?? '\u00A0',
                  style: TextStyle(
                    fontSize: 11,
                    color: hero.hfg.withValues(alpha: .75),
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

/// The placeholder portrait with a gear badge. Opens settings.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.onTap});

  final VoidCallback onTap;

  static const String _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 44 44">
  <circle cx="22" cy="22" r="22" fill="#fff" opacity=".16"/>
  <circle cx="22" cy="22" r="20" fill="#DDE5F0"/>
  <circle cx="22" cy="17" r="7" fill="#8FA3BF"/>
  <path d="M6 42c1.6-9 8-13.5 16-13.5S36.4 33 38 42z" fill="#8FA3BF"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    final hero = context.hero;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(child: SvgPicture.string(_svg, width: 44, height: 44)),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hero.hbg,
                  shape: BoxShape.circle,
                  border: Border.all(color: hero.hbg, width: 1.5),
                ),
                child: Icon(Ph.gearFill, size: 10, color: hero.hfg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final hero = context.hero;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: hero.hchip, shape: BoxShape.circle),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(Ph.bell, size: 17, color: hero.hfg),
            if (unread > 0)
              Positioned(
                top: 1,
                right: 1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: pal.act, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Flag, code, and the swap glyph.
///
/// A tap cycles through the favourites (EGP, USD) rather than opening a
/// picker — that is what the source does, and it makes the common switch one
/// tap instead of three.
class _CurrencyButton extends StatelessWidget {
  const _CurrencyButton({required this.money, required this.onTap});

  final Money money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hero = context.hero;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
        decoration: BoxDecoration(
          color: hero.hchip,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(kFlagSvg[money.code] ?? kFlagSvg['EGP']!,
                width: 21, height: 14),
            const SizedBox(width: 6),
            Text(money.code,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hero.hfg,
                )),
            const SizedBox(width: 6),
            Icon(Ph.arrowsLeftRight,
                size: 11, color: hero.hfg.withValues(alpha: .7)),
          ],
        ),
      ),
    );
  }
}

/// The flag SVGs, copied from the FLAG map in index.html.
const Map<String, String> kFlagSvg = {
  'EGP': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 21 14">'
      '<rect width="21" height="4.67" fill="#CE1126"/>'
      '<rect y="4.67" width="21" height="4.66" fill="#fff"/>'
      '<rect y="9.33" width="21" height="4.67" fill="#000"/>'
      '<circle cx="10.5" cy="7" r="1.6" fill="#C09300"/></svg>',
  'USD': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 21 14">'
      '<rect width="21" height="14" fill="#fff"/><g fill="#B22234">'
      '<rect width="21" height="1.6"/><rect y="3.2" width="21" height="1.6"/>'
      '<rect y="6.4" width="21" height="1.6"/><rect y="9.6" width="21" height="1.6"/>'
      '<rect y="12.8" width="21" height="1.2"/></g>'
      '<rect width="9" height="7.5" fill="#3C3B6E"/></svg>',
  'EUR': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 21 14">'
      '<rect width="21" height="14" fill="#039"/>'
      '<circle cx="10.5" cy="7" r="3.4" fill="none" stroke="#FC0" '
      'stroke-width="1" stroke-dasharray="1 1.4"/></svg>',
  'SAR': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 21 14">'
      '<rect width="21" height="14" fill="#165D31"/>'
      '<rect x="4" y="5.6" width="13" height="1.1" fill="#fff"/>'
      '<rect x="4" y="8.4" width="9" height="1.4" fill="#fff"/></svg>',
};

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hero = context.hero;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? hero.chipOn : hero.chipOff,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Opacity(
          opacity: selected ? 1 : .6,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: hero.chipTx,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
