// navRow() and row() from paintStatic()/paintSettings(), plus the small grey
// section captions that separate every block on these screens.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/ph.dart';

/// `<p class="text-[12px] text-mute pt-6 pb-2 px-1">`
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.top = 24});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4, top, 4, 8),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: context.pal.mute)),
      );
}

/// navRow(ic, title, subtitle) — a 40px tinted icon tile, two lines of text,
/// and a caret. Used all through Discover.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.first = false,
    this.iconSize = 40,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Settings rows put a value here instead of a subtitle.
  final String? trailingText;
  final bool first;

  /// 40 on Discover, 36 on Settings.
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border(
            top: first ? BorderSide.none : BorderSide(color: pal.line),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.tint,
                borderRadius: BorderRadius.circular(iconSize >= 40 ? 12 : 10),
              ),
              child: Icon(icon,
                  size: iconSize >= 40 ? 19 : 17, color: pal.actDk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: subtitle == null
                            ? FontWeight.w400
                            : FontWeight.w500,
                        color: pal.ink,
                      )),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(fontSize: 11, color: pal.mute)),
                ],
              ),
            ),
            if (trailingText != null) ...[
              Text(trailingText!,
                  style: TextStyle(fontSize: 12.5, color: pal.mute)),
              const SizedBox(width: 8),
            ],
            Icon(Ph.caretRight, size: 13, color: pal.mute),
          ],
        ),
      ),
    );
  }
}

/// The screen header used by Discover, Markets and Portfolio: a 22px title
/// with an optional subtitle and trailing action.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: TextStyle(fontSize: 11.5, color: pal.mute)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// The round icon button in a screen header, e.g. Markets' search.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: pal.p1, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: pal.ink),
      ),
    );
  }
}
