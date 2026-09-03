// The five-plus-one tab bar.
//
// The web build deliberately does NOT use the icon font here — the icons are
// inline SVG so navigation still works if the icon font fails to load. The
// path data below is copied verbatim from index.html for that reason.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/tokens.dart';

class TabSpec {
  const TabSpec(this.id, this.label, this.body);

  final String id;
  final String label;

  /// The inner markup of the 24x24 viewBox, stroked with currentColor.
  final String body;
}

const List<TabSpec> kTabs = [
  TabSpec('home', 'Home',
      '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>'),
  TabSpec('discover', 'Discover',
      '<circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5z"/>'),
  TabSpec('markets', 'Markets',
      '<path d="M3 17.5 9 11l4 3.5L21 6"/><path d="M21 6h-5m5 0v5"/>'),
  TabSpec('portfolio', 'Portfolio',
      '<path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/>'
      '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M3 12h18"/>'),
  TabSpec('money', 'Money',
      '<rect x="3" y="5" width="18" height="14" rx="2"/>'
      '<path d="M3 10h18"/><circle cx="17" cy="14" r="1.2"/>'),
  TabSpec('settings', 'Settings',
      '<circle cx="12" cy="12" r="3.2"/>'
      '<path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1A1.6 1.6 0 0 0 9 19.4a1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.6 1.6 0 0 0 4.6 9a1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z"/>'),
];

class XTabBar extends StatelessWidget {
  const XTabBar({super.key, required this.current, required this.onTap});

  final String current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: pal.p1,
        border: Border(top: BorderSide(color: pal.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final t in kTabs)
              Expanded(
                child: _Tab(
                  spec: t,
                  active: t.id == current,
                  onTap: () => onTap(t.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.spec, required this.active, required this.onTap});

  final TabSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final colour = active ? pal.act : pal.mute;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="currentColor" stroke-width="1.7" '
        'stroke-linecap="round" stroke-linejoin="round">${spec.body}</svg>';

    return Semantics(
      button: true,
      selected: active,
      label: spec.label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.string(
                svg,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(colour, BlendMode.srcIn),
              ),
              const SizedBox(height: 4),
              Text(
                spec.label,
                style: T.tab.copyWith(
                  color: colour,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
