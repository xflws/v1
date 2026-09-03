// The floating voice button — ports fabInit / fabPlace / fabSnap / fabBounds.
//
// It is draggable, snaps to whichever edge is nearer on release, and keeps its
// position across launches. Bounds are clamped so it can never sit under the
// tab bar or above the header.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/tokens.dart';
import '../core/ph.dart';

class VoiceFab extends StatefulWidget {
  const VoiceFab({super.key, required this.onTap, this.visible = true});

  final VoidCallback onTap;
  final bool visible;

  static const double size = 46;

  /// Clearance for the header and the tab bar, from fabBounds().
  static const double topInset = 64;
  static const double bottomInset = 96 + 8;
  static const double sideInset = 8;

  @override
  State<VoiceFab> createState() => _VoiceFabState();
}

class _VoiceFabState extends State<VoiceFab>
    with SingleTickerProviderStateMixin {
  Offset? _pos;
  bool _dragging = false;
  double _moved = 0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  static const String _key = 'xflws.fab';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || !mounted) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _pos =
          Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()));
    } catch (_) {
      // No saved position; the default corner stands.
    }
  }

  Future<void> _save(Offset p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({'x': p.dx, 'y': p.dy}));
    } catch (_) {}
  }

  ({double left, double right, double top, double bottom}) _bounds(Size s) => (
        left: VoiceFab.sideInset,
        right: s.width - VoiceFab.size - VoiceFab.sideInset,
        top: VoiceFab.topInset,
        bottom: s.height - VoiceFab.size - VoiceFab.bottomInset,
      );

  Offset _clamp(Offset p, Size s) {
    final b = _bounds(s);
    return Offset(
      p.dx.clamp(b.left, b.right < b.left ? b.left : b.right),
      p.dy.clamp(b.top, b.bottom < b.top ? b.top : b.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final pal = context.pal;

    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final b = _bounds(size);
        final pos = _clamp(
          _pos ?? Offset(b.right, b.bottom),
          size,
        );

        return Stack(
          children: [
            AnimatedPositioned(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: pos.dx,
              top: pos.dy,
              child: Listener(
                onPointerDown: (_) => setState(() {
                  _dragging = true;
                  _moved = 0;
                }),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    _moved += d.delta.distance;
                    setState(() => _pos = _clamp(pos + d.delta, size));
                  },
                  onPanEnd: (_) {
                    // Snap to the nearer edge, as the source does.
                    final mid = (b.left + b.right) / 2;
                    final snapped =
                        Offset(pos.dx < mid ? b.left : b.right, pos.dy);
                    setState(() {
                      _pos = snapped;
                      _dragging = false;
                    });
                    _save(snapped);
                  },
                  onTap: () {
                    // A drag must not open the sheet on release.
                    if (_moved < 6) widget.onTap();
                  },
                  child: SizedBox(
                    width: VoiceFab.size,
                    height: VoiceFab.size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The slow outward pulse.
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) => Opacity(
                            opacity: (1 - _pulse.value) * 0.32,
                            child: Transform.scale(
                              scale: 1 + _pulse.value * 0.6,
                              child: Container(
                                width: VoiceFab.size,
                                height: VoiceFab.size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: pal.act, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: VoiceFab.size,
                          height: VoiceFab.size,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [pal.act, const Color(0xFFE4610F)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: pal.act.withValues(alpha: .38),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Text(
                            'X',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
