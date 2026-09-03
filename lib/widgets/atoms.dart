// The small helpers index.html reuses everywhere: mark(), stack(), pctTag(),
// compact(), card(), statTile(), pill(), emptyState().
//
// Ported verbatim — sizes, radii, font sizes and colours are the source's, not
// approximations.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';

/// `compact(v)` — thousands become "406.51k", below that two decimals.
String compact(num egp, Money money) {
  final c = money.convert(egp);
  return c >= 1000
      ? '${(c / 1000).toStringAsFixed(2)}k'
      : c.toStringAsFixed(2);
}

/// `pctTag(d, up)` — "▲ 1.38%" in gain or loss. 11px, tabular.
class PctTag extends StatelessWidget {
  const PctTag({super.key, required this.delta, this.up, this.fontSize = 11});

  final num delta;

  /// The source passes `up` separately, because a group's delta is signed but
  /// a holding's is an absolute value with a separate direction flag.
  final bool? up;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final rising = up ?? delta > 0;
    return Text(
      '${rising ? '\u25B2' : '\u25BC'} ${delta.abs().toStringAsFixed(2)}%',
      style: TextStyle(
        fontSize: fontSize,
        color: rising ? pal.gain : pal.loss,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// `mark(m, bg, t, size)` — the coloured monogram tile with the logo layered
/// over it. The logo simply removes itself if it fails to load, which is why
/// the monogram sits underneath rather than beside.
class Mark extends StatelessWidget {
  const Mark({
    super.key,
    required this.monogram,
    required this.colour,
    this.ticker,
    this.size = 36,
    this.logoUrl,
  });

  final String monogram;
  final Color colour;
  final String? ticker;
  final double size;
  final String Function(String ticker)? logoUrl;

  @override
  Widget build(BuildContext context) {
    final url = (ticker == null || ticker!.isEmpty) ? null : logoUrl?.call(ticker!);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              monogram,
              style: TextStyle(
                color: Colors.white,
                fontSize: size < 28 ? 9 : 11,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          if (url != null)
            Image.network(
              url,
              fit: BoxFit.cover,
              // Nothing is drawn while loading or on failure, so the monogram
              // beneath shows through — same as the source's onerror remove.
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              loadingBuilder: (_, child, p) =>
                  p == null ? child : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// `stack(rows, size)` — overlapping tiles, each pulled 7px over the last and
/// ringed in the card colour.
class MarkStack extends StatelessWidget {
  const MarkStack({
    super.key,
    required this.items,
    this.size = 26,
    this.logoUrl,
  });

  /// (monogram, colour, ticker)
  final List<(String, Color, String)> items;
  final double size;
  final String Function(String ticker)? logoUrl;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox(
      height: size + 4,
      width: items.isEmpty ? 0 : size + (items.length - 1) * (size - 7) + 4,
      child: Stack(
        children: [
          for (var i = 0; i < items.length; i++)
            Positioned(
              left: i * (size - 7),
              top: 2,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size / 3),
                  border: Border.all(color: pal.p2, width: 2),
                ),
                child: Mark(
                  monogram: items[i].$1,
                  colour: items[i].$2,
                  ticker: items[i].$3,
                  size: size,
                  logoUrl: logoUrl,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `card(inner)` — rounded-2xl, paper 2, hairline border, clipped.
class InnerCard extends StatelessWidget {
  const InnerCard({super.key, required this.child, this.margin});

  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: margin ?? const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.p2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.line),
      ),
      child: child,
    );
  }
}

/// `statTile(label, val, tone)`.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.tone,
  });

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.p1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10.5, height: 1, color: pal.mute)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tone ?? pal.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

/// The TONE map the source uses for pills.
class Tone {
  const Tone(this.bg, this.fg);

  final Color bg;
  final Color fg;

  static Tone ok(BuildContext c) => Tone(c.pal.tint, c.pal.actDk);
  static Tone gain(BuildContext c) =>
      Tone(c.pal.gain.withValues(alpha: .10), c.pal.gain);
  static Tone loss(BuildContext c) =>
      Tone(c.pal.loss.withValues(alpha: .10), c.pal.loss);
  static Tone mute(BuildContext c) =>
      Tone(c.pal.p1, c.pal.mute);
}

/// `pill(text, tone, ic)`.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, required this.tone, this.icon});

  final String text;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: tone.fg),
              const SizedBox(width: 4),
            ],
            Text(text, style: TextStyle(fontSize: 11, color: tone.fg)),
          ],
        ),
      );
}

/// `emptyState(icon, title, body, cta, attrs)`.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: pal.p1, shape: BoxShape.circle),
            child: Icon(icon, size: 26, color: pal.mute),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: pal.ink,
              )),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: pal.mute)),
          if (ctaLabel != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onCta,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: pal.act,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(ctaLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    )),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Phosphor icon per asset class, from DICON.
const Map<String, IconData> kGroupIcon = {
  'Stocks': Ph.chartBar,
  'Funds': Ph.chartPieSlice,
  'Metal funds': Ph.coins,
  'Cash': Ph.wallet,
};
