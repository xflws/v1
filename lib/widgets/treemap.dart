// The allocation treemap.
//
// `squarify()` ported line for line — a classic squarified treemap, which keeps
// rectangles close to square so the ticker labels actually fit inside them.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../data/models.dart';

/// PIE_COL — [face, side] per asset class. The face colour is what the treemap
/// paints; the second is the 3D pie's shaded side.
const Map<String, List<Color>> kPieColour = {
  'Stocks': [Color(0xFF0E8F80), Color(0xFF0A6357)],
  'Funds': [Color(0xFF062E54), Color(0xFF04213D)],
  'Metal funds': [Color(0xFFF0932B), Color(0xFFB96C13)],
  'Gold': [Color(0xFFF0932B), Color(0xFFB96C13)],
  'Cash': [Color(0xFF8A98A5), Color(0xFF5F6C78)],
  'Certificates': [Color(0xFF7B5EA7), Color(0xFF523B75)],
  'Savings plans': [Color(0xFF3FA796), Color(0xFF2A7266)],
  'Margin': [Color(0xFFC0567A), Color(0xFF8A3454)],
};

const List<Color> kPieFallback = [Color(0xFF8A98A5), Color(0xFF5F6C78)];

List<Color> pieColour(String group) => kPieColour[group] ?? kPieFallback;

class TreeCell {
  TreeCell(this.key, this.label, this.name, this.group, this.value, this.rect,
      this.percent);

  final String key;
  final String label;
  final String name;
  final String group;
  final num value;
  final Rect rect;
  final double percent;
}

class _Item {
  _Item(this.key, this.label, this.name, this.group, this.value, this.percent);

  final String key;
  final String label;
  final String name;
  final String group;
  final num value;
  final double percent;
}

/// The squarified layout. Rows are accumulated while the worst aspect ratio
/// keeps improving, then laid down across the short side of what is left.
List<TreeCell> squarify(List<_Item> items, double x, double y, double w, double h) {
  final out = <TreeCell>[];
  final list = items.toList()..sort((a, b) => b.value.compareTo(a.value));

  var cx = x, cy = y, cw = w, ch = h;

  while (list.isNotEmpty) {
    final horizontal = cw >= ch;
    final side = horizontal ? ch : cw;
    final remaining = list.fold<num>(0, (a, i) => a + i.value);
    if (remaining <= 0 || side <= 0) break;
    final scale = (cw * ch) / remaining;

    var row = <_Item>[];
    var best = double.infinity;

    for (var n = 1; n <= list.length; n++) {
      final cand = list.take(n).toList();
      final sum = cand.fold<num>(0, (a, i) => a + i.value) * scale;
      final thick = sum / side;
      if (thick <= 0) break;
      var worst = 0.0;
      for (final i in cand) {
        final len = (i.value * scale) / thick;
        if (len <= 0) continue;
        final r = thick / len > len / thick ? thick / len : len / thick;
        if (r > worst) worst = r.toDouble();
      }
      if (worst <= best) {
        best = worst;
        row = cand;
      } else {
        break;
      }
    }

    if (row.isEmpty) break;

    final sum = row.fold<num>(0, (a, i) => a + i.value) * scale;
    final thick = sum / side;
    var off = 0.0;

    for (final i in row) {
      final len = (i.value * scale) / thick;
      out.add(TreeCell(
        i.key,
        i.label,
        i.name,
        i.group,
        i.value,
        horizontal
            ? Rect.fromLTWH(cx, cy + off, thick, len)
            : Rect.fromLTWH(cx + off, cy, len, thick),
        i.percent,
      ));
      off += len;
    }

    if (horizontal) {
      cx += thick;
      cw -= thick;
    } else {
      cy += thick;
      ch -= thick;
    }
    list.removeRange(0, row.length);
  }

  return out;
}

class _TreemapPainter extends CustomPainter {
  _TreemapPainter({required this.cells, this.selected});

  final List<TreeCell> cells;
  final String? selected;

  /// GAP in the source.
  static const double gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in cells) {
      final dim = selected != null && selected != c.key;
      final r = c.rect;
      final rect = Rect.fromLTWH(
        r.left + gap / 2,
        r.top + gap / 2,
        (r.width - gap).clamp(0, double.infinity),
        (r.height - gap).clamp(0, double.infinity),
      );
      if (rect.width <= 0 || rect.height <= 0) continue;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = pieColour(c.group).first.withValues(alpha: dim ? .35 : 1),
      );

      final wide = r.width > 52 && r.height > 30;
      final tiny = r.width < 26 || r.height < 18;
      if (tiny) continue;

      _text(canvas, c.label, Offset(r.left + 8, r.top + 8),
          size: wide ? 11 : 9.5,
          weight: FontWeight.w700,
          opacity: dim ? .5 : .96);

      if (wide) {
        _text(canvas, '${c.percent.toStringAsFixed(1)}%',
            Offset(r.left + 8, r.top + 22),
            size: 9.5, weight: FontWeight.w400, opacity: dim ? .4 : .72);
      }
    }
  }

  void _text(Canvas canvas, String s, Offset at,
      {required double size,
      required FontWeight weight,
      required double opacity}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          fontWeight: weight,
          fontFamily: 'Cairo',
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_TreemapPainter old) =>
      old.cells != cells || old.selected != selected;
}

/// The treemap with its legend, as `portfolioView()` renders in 'figure' mode.
class AllocationTreemap extends StatefulWidget {
  const AllocationTreemap({super.key, required this.portfolio});

  final Portfolio portfolio;

  /// The source's fixed viewBox.
  static const double w = 340;
  static const double h = 210;

  @override
  State<AllocationTreemap> createState() => _AllocationTreemapState();
}

class _AllocationTreemapState extends State<AllocationTreemap> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final total = Portfolio.groupOrder
        .fold<num>(0, (a, g) => a + widget.portfolio.groupTotal(g));
    if (total <= 0) return const SizedBox.shrink();

    final items = [
      for (final h in widget.portfolio.holdings.where((h) => h.value > 0))
        _Item(
          h.ticker.isEmpty ? h.name : h.ticker,
          h.ticker.isEmpty ? 'CASH' : h.ticker,
          h.name,
          h.group,
          h.value,
          (h.value / total * 100).toDouble(),
        )
    ];

    final cells = squarify(
        items, 0, 0, AllocationTreemap.w, AllocationTreemap.h);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: AllocationTreemap.w / AllocationTreemap.h,
          child: LayoutBuilder(
            builder: (context, c) {
              final scale = c.maxWidth / AllocationTreemap.w;
              return GestureDetector(
                onTapDown: (d) {
                  final p = d.localPosition / scale;
                  final hit = cells.where((x) => x.rect.contains(p));
                  setState(() => _selected =
                      hit.isEmpty || hit.first.key == _selected
                          ? null
                          : hit.first.key);
                },
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: AllocationTreemap.w,
                    height: AllocationTreemap.h,
                    child: CustomPaint(
                      painter:
                          _TreemapPainter(cells: cells, selected: _selected),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final g in Portfolio.groupOrder
                .where((g) => widget.portfolio.groupTotal(g) > 0))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: pieColour(g).first,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(g,
                      style: TextStyle(fontSize: 11, color: pal.ink)),
                  const SizedBox(width: 4),
                  Text(
                    '${(widget.portfolio.groupTotal(g) / total * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: pal.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
