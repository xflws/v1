// The hero net-worth chart and the small sparklines.
//
// Ports drawChart() / scrub() from index.html: a stroked line with a fade to
// transparent underneath, a draw-on animation, and a crosshair with a haloed
// dot that follows the finger and pushes the value back up into the header.
import 'package:flutter/material.dart';
import '../core/tokens.dart';

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.colour,
    required this.progress,
    required this.fill,
    this.scrubIndex,
    this.strokeWidth = 2.6,
    this.topPad = 14,
    this.bottomPad = 26,
    this.ringColour,
  });

  final List<num> values;
  final Color colour;

  /// 0..1 draw-on. 1 means fully drawn.
  final double progress;
  final bool fill;
  final int? scrubIndex;
  final double strokeWidth;
  final double topPad;
  final double bottomPad;

  /// The hero background, painted as a ring around the scrub dot.
  final Color? ringColour;

  List<Offset> _points(Size size) {
    if (values.length < 2) return const [];
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final range = (hi - lo) == 0 ? 1 : (hi - lo);
    final usable = size.height - topPad - bottomPad;
    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          i / (values.length - 1) * size.width,
          size.height - bottomPad - ((values[i] - lo) / range) * usable,
        )
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = _points(size);
    if (pts.isEmpty) return;

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colour.withValues(alpha: 0.34 * progress), colour.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }

    // Draw-on: reveal a leading fraction of the measured path.
    Path visible = path;
    if (progress < 1) {
      final metrics = path.computeMetrics().toList();
      visible = Path();
      for (final m in metrics) {
        visible.addPath(m.extractPath(0, m.length * progress), Offset.zero);
      }
    }

    canvas.drawPath(
      visible,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colour,
    );

    // The baseline the source draws at y=126 of a 128 viewBox.
    canvas.drawLine(
      Offset(0, size.height - 2),
      Offset(size.width, size.height - 2),
      Paint()
        ..strokeWidth = 1
        ..color = colour.withValues(alpha: 0.24),
    );

    final i = scrubIndex;
    if (i != null && i >= 0 && i < pts.length) {
      final p = pts[i];
      // Dashed crosshair the full height, as the source's stroke-dasharray
      // "3 3" line does.
      const dash = 3.0;
      for (var y = 0.0; y < size.height; y += dash * 2) {
        canvas.drawLine(
          Offset(p.dx, y),
          Offset(p.dx, (y + dash).clamp(0, size.height)),
          Paint()
            ..strokeWidth = 1
            ..color = colour.withValues(alpha: 0.7),
        );
      }
      // A 24px halo under a 14px dot ringed in the hero colour.
      canvas.drawCircle(p, 12, Paint()..color = colour.withValues(alpha: 0.18));
      canvas.drawCircle(p, 7, Paint()..color = colour);
      if (ringColour != null) {
        canvas.drawCircle(
          p,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = ringColour!,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.progress != progress ||
      old.scrubIndex != scrubIndex ||
      old.colour != colour;
}

/// The large hero chart. Drag across it to scrub; [onScrub] reports the index
/// under the finger and null on release, so the header can restore itself.
class HeroChart extends StatefulWidget {
  const HeroChart({
    super.key,
    required this.values,
    this.height = 128,
    this.onScrub,
  });

  final List<num> values;
  final double height;
  final void Function(int? index)? onScrub;

  @override
  State<HeroChart> createState() => _HeroChartState();
}

class _HeroChartState extends State<HeroChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward();

  int? _scrub;

  @override
  void didUpdateWidget(HeroChart old) {
    super.didUpdateWidget(old);
    // A range change redraws from scratch, as the web build does.
    if (old.values != widget.values) _draw.forward(from: 0);
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _update(Offset local, double width) {
    if (widget.values.length < 2) return;
    final f = (local.dx / width).clamp(0.0, 1.0);
    final i = (f * (widget.values.length - 1)).round();
    if (i == _scrub) return;
    setState(() => _scrub = i);
    widget.onScrub?.call(i);
  }

  void _release() {
    if (_scrub == null) return;
    setState(() => _scrub = null);
    widget.onScrub?.call(null);
    // Scrubbing cancels the reveal, matching the original.
    _draw.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final hero = context.hero;
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => _update(d.localPosition, c.maxWidth),
        onHorizontalDragUpdate: (d) => _update(d.localPosition, c.maxWidth),
        onHorizontalDragEnd: (_) => _release(),
        onHorizontalDragCancel: _release,
        onTapDown: (d) => _update(d.localPosition, c.maxWidth),
        onTapUp: (_) => _release(),
        child: AnimatedBuilder(
          animation: _draw,
          builder: (context, _) => CustomPaint(
            size: Size(c.maxWidth, widget.height),
            painter: _LinePainter(
              values: widget.values,
              colour: hero.chart,
              progress: _scrub == null ? _draw.value : 1,
              fill: true,
              scrubIndex: _scrub,
              ringColour: hero.hbg,
            ),
          ),
        ),
      ),
    );
  }
}

/// The small green/red line on index rows and movers.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.up,
    this.width = 56,
    this.height = 24,
  });

  final List<num> values;
  final bool up;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return CustomPaint(
      size: Size(width, height),
      painter: _LinePainter(
        values: values,
        colour: up ? pal.gain : pal.loss,
        progress: 1,
        fill: false,
        strokeWidth: 1.6,
        topPad: 3,
        bottomPad: 3,
      ),
    );
  }
}
