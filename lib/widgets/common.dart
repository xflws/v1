// Primitives that repeat across every screen. Sizes and radii match the
// Tailwind classes used in index.html.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';

/// The raised white card everything sits on (bg-pap2, rounded-2xl).
class Card2 extends StatelessWidget {
  const Card2({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.bordered = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: pal.p2,
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: pal.line) : null,
      ),
      child: child,
    );
  }
}

/// Hairline section divider (border-t border-line).
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, indent: indent, color: context.pal.line);
}

/// Section header with an optional trailing action, e.g. "My portfolio · Show all".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: T.section.copyWith(color: pal.ink))),
          if (trailing != null) trailing!,
          if (actionLabel != null) ...[
            const SizedBox(width: 14),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: T.label.copyWith(
                  color: pal.actDk,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The coloured two-letter tile shown when no logo PNG exists, and the logo
/// when one does. Falls back silently — the app must work with none, some or
/// all logos present.
class TickerTile extends StatelessWidget {
  const TickerTile({
    super.key,
    required this.monogram,
    required this.colour,
    this.logoUrl,
    this.size = 38,
  });

  final String monogram;
  final Color colour;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Text(
        monogram.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );

    if (logoUrl == null) return tile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.29),
      child: Image.network(
        logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => tile,
        loadingBuilder: (_, child, p) => p == null ? child : tile,
      ),
    );
  }
}

/// Pill chip. Used for ranges (1D/1W/1M/1Y/All) and filters.
class Chip2 extends StatelessWidget {
  const Chip2({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onHero = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// True when sitting on the hero card, which has its own chip colours.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final hero = context.hero;
    final bg = onHero
        ? (selected ? hero.chipOn : hero.chipOff)
        : (selected ? pal.tint : pal.p1);
    final fg = onHero ? hero.chipTx : (selected ? pal.actDk : pal.ink);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: T.chip.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// "+1.38%" in gain green or loss red.
class DeltaText extends StatelessWidget {
  const DeltaText({super.key, required this.percent, this.style});

  final num percent;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Text(
      Money.percent(percent),
      style: (style ?? T.rowSub).copyWith(
        color: percent >= 0 ? pal.gain : pal.loss,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// A holding or instrument row: tile, name over subtitle, value over delta.
class AssetRow extends StatelessWidget {
  const AssetRow({
    super.key,
    required this.tile,
    required this.name,
    required this.subtitle,
    required this.value,
    required this.percent,
    this.onTap,
  });

  final Widget tile;
  final String name;
  final String subtitle;
  final String value;
  final num percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            tile,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.rowName.copyWith(color: pal.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.rowSub.copyWith(color: pal.mute)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: T.rowName.copyWith(
                        color: pal.ink, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                DeltaText(percent: percent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton block shown while a screen's data is in flight.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 14, this.width, this.radius = 6});

  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(_c),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: pal.p0,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
