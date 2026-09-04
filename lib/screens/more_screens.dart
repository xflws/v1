// The remaining pushed screens: Savings, T-Bills & Bonds, Investment
// calculator, Learning hub, Community and the AI assistant.
//
// Each keeps the source's header shape: a back button, a 17px title and an
// 11.5px subtitle.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/api.dart';
import '../widgets/atoms.dart';
import '../widgets/chart.dart';
import '../widgets/hero_header.dart' show kFlagSvg;
import 'package:flutter_svg/flutter_svg.dart';

/// The shared header for every pushed screen.
class PushedHeader extends StatelessWidget {
  const PushedHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: pal.p1, shape: BoxShape.circle),
                child: Icon(Ph.caretLeft, size: 15, color: pal.ink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(fontSize: 11.5, color: pal.mute)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _label(BuildContext context, String s, {double top = 16}) => Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 4),
      child: Text(s, style: TextStyle(fontSize: 12, color: context.pal.mute)),
    );

// ── Savings ──────────────────────────────────────────────────────────────

const List<(String, String, double, String)> kAccounts = [
  ('EGP', 'Current account', 3410.00, '21.0% a year, paid daily'),
  ('USD', 'Current account', 1250.00, '4.2% a year, paid daily'),
];

const List<(String, num, num, IconData, String)> kGoals = [
  ('Emergency fund', 100000, 64500, Ph.umbrella, 'Dec 2026'),
  ('Hajj', 250000, 42000, Ph.moonStars, '2028'),
  ('New car', 600000, 120000, Ph.car, '2029'),
];

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key, required this.money});

  final Money money;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Savings', subtitle: 'Accounts, goals and plans'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(context, 'Accounts'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < kAccounts.length; i++)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border(
                              top: i == 0
                                  ? BorderSide.none
                                  : BorderSide(color: pal.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              SvgPicture.string(
                                  kFlagSvg[kAccounts[i].$1] ?? kFlagSvg['EGP']!,
                                  width: 21,
                                  height: 14),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${kAccounts[i].$2} \u00B7 ${kAccounts[i].$1}',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: pal.ink,
                                        )),
                                    Text(kAccounts[i].$4,
                                        style: TextStyle(
                                            fontSize: 11, color: pal.mute)),
                                  ],
                                ),
                              ),
                              Text(
                                kAccounts[i].$3.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: pal.ink,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _dashedRow(context, Ph.plus, 'Open a new account'),
                _label(context, 'Goals'),
                for (final g in kGoals) _goal(context, g),
                const SizedBox(height: 10),
                _dashedRow(context, Ph.target, 'Create a goal'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedRow(BuildContext context, IconData ic, String label) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.line, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: pal.tint, shape: BoxShape.circle),
            child: Icon(ic, size: 18, color: pal.act),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: pal.ink,
              )),
        ],
      ),
    );
  }

  Widget _goal(BuildContext context, (String, num, num, IconData, String) g) {
    final pal = context.pal;
    final pc = (g.$3 / g.$2).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.p2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pal.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(g.$4, size: 17, color: pal.actDk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.$1,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: pal.ink,
                        )),
                    Text('by ${g.$5}',
                        style: TextStyle(fontSize: 11, color: pal.mute)),
                  ],
                ),
              ),
              Text(
                '${money.format(g.$3)} / ${money.format(g.$2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: pal.mute,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pc,
              minHeight: 6,
              backgroundColor: pal.p1,
              valueColor: AlwaysStoppedAnimation(pal.act),
            ),
          ),
        ],
      ),
    );
  }
}

// ── T-Bills and bonds ────────────────────────────────────────────────────

const List<(String, String, double, String, num, String)> kTbills = [
  ('T-Bill 91d', 'Egyptian treasury bill', 26.4, '91 days', 25000, 'Government'),
  ('T-Bill 182d', 'Egyptian treasury bill', 25.8, '182 days', 25000, 'Government'),
  ('T-Bill 364d', 'Egyptian treasury bill', 24.9, '364 days', 25000, 'Government'),
  ('Bond 3Y', 'Government bond', 22.5, '3 years', 50000, 'Government'),
  ('Bond 5Y', 'Government bond', 21.8, '5 years', 50000, 'Government'),
  ('Sukuk AA', 'Sovereign sukuk \u00B7 Sharia', 20.9, '3 years', 10000, 'Sukuk'),
  ('Corp 2Y', 'Corporate bond \u00B7 AA rated', 23.6, '2 years', 100000, 'Corporate'),
];

class TbillsScreen extends StatefulWidget {
  const TbillsScreen({super.key, required this.money});

  final Money money;

  @override
  State<TbillsScreen> createState() => _TbillsScreenState();
}

class _TbillsScreenState extends State<TbillsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const kinds = ['All', 'Government', 'Sukuk', 'Corporate'];
    final rows =
        kTbills.where((x) => _filter == 'All' || x.$6 == _filter).toList();

    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'T-Bills & Bonds',
              subtitle: 'Government and corporate debt'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final k in kinds) ...[
                        GestureDetector(
                          onTap: () => setState(() => _filter = k),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: k == _filter ? pal.act : pal.p1,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(k,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      k == _filter ? Colors.white : pal.ink,
                                )),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                _label(context, '${rows.length} available'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        GestureDetector(
                          onTap: () => _showTbillDetail(context, rows[i]),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border(
                                top: i == 0
                                    ? BorderSide.none
                                    : BorderSide(color: pal.line),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: pal.tint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                    rows[i].$6 == 'Sukuk'
                                        ? Ph.moonStars
                                        : Ph.receipt,
                                    size: 18,
                                    color: pal.actDk),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(rows[i].$1,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: pal.ink,
                                        )),
                                    Text(
                                      '${rows[i].$2} \u00B7 ${rows[i].$4} \u00B7 '
                                      'min ${widget.money.format(rows[i].$5)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                                    '${rows[i].$3.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: pal.gain,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                  Text('a year',
                                      style: TextStyle(
                                          fontSize: 10, color: pal.mute)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Yields are indicative and set at auction. Holding to '
                  'maturity returns the face value; selling earlier returns '
                  'the market price, which can be lower.',
                  style: TextStyle(
                      fontSize: 11.5, height: 1.375, color: pal.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTbillDetail(
      BuildContext context, (String, String, double, String, num, String) t) {
    final pal = context.pal;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.p2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              const SizedBox(height: 16),
              Text(t.$1,
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600,
                    color: pal.ink,
                  )),
              Text('${t.$2} · ${t.$4}',
                  style: TextStyle(fontSize: 12, color: pal.mute)),
              const SizedBox(height: 16),
              _factRow(context, 'Yield', '${t.$3.toStringAsFixed(1)}% a year'),
              _factRow(context, 'Maturity', t.$4),
              _factRow(context, 'Minimum investment',
                  widget.money.format(t.$5)),
              _factRow(context, 'Type', t.$6),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(sheet).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.act,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Invest',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500,
                        color: Colors.white,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _factRow(BuildContext context, String label, String value) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: pal.mute)),
          Text(value,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: pal.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

// ── Investment calculator ────────────────────────────────────────────────

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, required this.money});

  final Money money;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  double _initial = 10000;
  double _monthly = 1000;
  double _years = 10;
  double _rate = 18;

  /// Future value of a lump sum plus a monthly contribution, compounded
  /// monthly.
  (num total, num paid, num growth) _run() {
    final r = _rate / 100 / 12;
    final n = _years * 12;
    final fvInitial = _initial * math.pow(1 + r, n);
    final fvMonthly =
        r == 0 ? _monthly * n : _monthly * ((math.pow(1 + r, n) - 1) / r);
    final total = fvInitial + fvMonthly;
    final paid = _initial + _monthly * n;
    return (total, paid, total - paid);
  }

  List<num> get _curve {
    final out = <num>[];
    final r = _rate / 100 / 12;
    for (var y = 0; y <= _years.round(); y++) {
      final n = y * 12;
      final fv = _initial * math.pow(1 + r, n) +
          (r == 0 ? _monthly * n : _monthly * ((math.pow(1 + r, n) - 1) / r));
      out.add(fv);
    }
    return out.length < 2 ? [0, 0] : out;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (total, paid, growth) = _run();

    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Investment calculator',
              subtitle: 'See what regular investing becomes'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('After ${_years.round()} years',
                            style:
                                TextStyle(fontSize: 11, color: pal.mute)),
                        const SizedBox(height: 4),
                        Text(
                          widget.money.format(total),
                          style: TextStyle(
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: pal.ink,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Sparkline(
                            values: _curve, up: true, width: 320, height: 60),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StatTile(
                                label: 'You put in',
                                value: widget.money.format(paid),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatTile(
                                label: 'Growth',
                                value: widget.money.format(growth),
                                tone: pal.gain,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _slider(context, 'Starting amount', _initial, 0, 500000, 1000,
                    (v) => setState(() => _initial = v),
                    display: widget.money.format(_initial)),
                _slider(context, 'Every month', _monthly, 0, 50000, 250,
                    (v) => setState(() => _monthly = v),
                    display: widget.money.format(_monthly)),
                _slider(context, 'For', _years, 1, 40, 1,
                    (v) => setState(() => _years = v),
                    display: '${_years.round()} years'),
                _slider(context, 'Assumed return', _rate, 0, 40, 0.5,
                    (v) => setState(() => _rate = v),
                    display: '${_rate.toStringAsFixed(1)}% a year'),
                const SizedBox(height: 12),
                Text(
                  'A projection, not a forecast. Real returns vary year to '
                  'year and can be negative; this assumes a steady rate, which '
                  'no market delivers.',
                  style: TextStyle(
                      fontSize: 11.5, height: 1.375, color: pal.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(BuildContext context, String label, double value, double min,
      double max, double step, ValueChanged<double> onChanged,
      {required String display}) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: pal.mute)),
              Text(display,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / step).round(),
            activeColor: pal.act,
            inactiveColor: pal.p1,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Learning hub ─────────────────────────────────────────────────────────

const List<(String, String, IconData, bool)> kLessons = [
  ('What a share actually is', '4 min \u00B7 beginner', Ph.certificate, true),
  ('Reading an order book', '6 min \u00B7 intermediate', Ph.listNumbers, true),
  ('Why funds price once a day', '3 min \u00B7 beginner', Ph.chartPieSlice, false),
  ('Treasury bills explained', '5 min \u00B7 beginner', Ph.receipt, false),
  ('Position sizing and risk', '8 min \u00B7 advanced', Ph.scales, false),
];

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final done = kLessons.where((l) => l.$4).length;

    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Learning hub',
              subtitle: 'Short lessons and paper trading'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Your progress',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: pal.ink,
                                )),
                            Text('$done of ${kLessons.length}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: pal.ink,
                                )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: done / kLessons.length,
                            minHeight: 8,
                            backgroundColor: pal.p1,
                            valueColor: AlwaysStoppedAnimation(pal.act),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: pal.ink,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paper trading',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        'Practise with 100,000 virtual EGP on live prices. '
                        'Nothing touches your real money.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.375,
                          color: Colors.white.withValues(alpha: .75),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Start practising',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            )),
                      ),
                    ],
                  ),
                ),
                _label(context, 'Lessons'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < kLessons.length; i++)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border(
                              top: i == 0
                                  ? BorderSide.none
                                  : BorderSide(color: pal.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: pal.tint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(kLessons[i].$3,
                                    size: 17, color: pal.actDk),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(kLessons[i].$1,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: pal.ink,
                                        )),
                                    Text(kLessons[i].$2,
                                        style: TextStyle(
                                            fontSize: 11, color: pal.mute)),
                                  ],
                                ),
                              ),
                              if (kLessons[i].$4)
                                Icon(Ph.checkCircleFill,
                                    size: 18, color: pal.gain)
                              else
                                Icon(Ph.caretRight,
                                    size: 13, color: pal.mute),
                            ],
                          ),
                        ),
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
}

// ── Community ────────────────────────────────────────────────────────────

const List<(String, String, String, int, double, String, bool)> kTraders = [
  ('@hazem.n', 'Hazem Nabil', 'Long-only Egyptian equities', 0xFF0E7C5A, 12.4,
      '18.2k', true),
  ('@mostafa', 'Mostafa Adel', 'Dividends and fixed income', 0xFF062E54, 8.1,
      '6.4k', true),
  ('@sara.k', 'Sara Kamal', 'Small caps, high conviction', 0xFF0FA3A3, 19.6,
      '3.1k', false),
];

const List<(String, String, String, String?, int, int)> kFeed = [
  ('@hazem.n', '2h',
      'Added to CLHO after the half-year numbers. Occupancy is up and the new '
          'Sheikh Zayed site opens in Q4.',
      'CLHO', 214, 31),
  ('@sara.k', '5h',
      'CPME up 18% in a session is not something to chase. I trimmed a third '
          'and left the rest running.',
      'CPME', 98, 12),
  ('@mostafa', 'Yesterday',
      'T-Bills at 26.4% still beat most equity risk-adjusted returns this '
          'year. I am rolling the 91-day again.',
      null, 341, 44),
];

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _tab = 'Feed';

  (String, int, bool) _who(String handle) {
    for (final t in kTraders) {
      if (t.$1 == handle) return (t.$2, t.$4, t.$7);
    }
    return (handle, 0xFF888888, false);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Community',
              subtitle: 'What other investors hold and say'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: pal.p1,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  for (final t in ['Feed', 'Investors', 'Following'])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: t == _tab ? pal.p2 : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(t,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: t == _tab
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: t == _tab ? pal.ink : pal.mute,
                              )),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: _tab == 'Feed' ? _feed(context) : _investors(context),
          ),
        ],
      ),
    );
  }

  Widget _feed(BuildContext context) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in kFeed)
          Builder(builder: (context) {
            final w = _who(f.$1);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.p2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pal.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: Color(w.$2), shape: BoxShape.circle),
                        child: Text(w.$1.substring(0, 1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(w.$1,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: pal.ink,
                                    )),
                                if (w.$3) ...[
                                  const SizedBox(width: 4),
                                  Icon(Ph.sealCheckFill,
                                      size: 13, color: pal.act),
                                ],
                              ],
                            ),
                            Text('${f.$1} \u00B7 ${f.$2}',
                                style: TextStyle(
                                    fontSize: 11, color: pal.mute)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(f.$3,
                      style: TextStyle(
                          fontSize: 13, height: 1.5, color: pal.ink)),
                  if (f.$4 != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Pill(text: f.$4!, tone: Tone.ok(context)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Ph.heart, size: 15, color: pal.mute),
                      const SizedBox(width: 5),
                      Text('${f.$5}',
                          style:
                              TextStyle(fontSize: 11.5, color: pal.mute)),
                      const SizedBox(width: 16),
                      Icon(Ph.chatCircle, size: 15, color: pal.mute),
                      const SizedBox(width: 5),
                      Text('${f.$6}',
                          style:
                              TextStyle(fontSize: 11.5, color: pal.mute)),
                    ],
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 4),
        Text(
          'Posts are opinions from other customers, not advice from XFLWS, '
          'and are not checked before publication.',
          style: TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
        ),
      ],
    );
  }

  Widget _investors(BuildContext context) {
    final pal = context.pal;
    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < kTraders.length; i++)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0 ? BorderSide.none : BorderSide(color: pal.line),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Color(kTraders[i].$4), shape: BoxShape.circle),
                    child: Text(kTraders[i].$2.substring(0, 1),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(kTraders[i].$2,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: pal.ink,
                                )),
                            if (kTraders[i].$7) ...[
                              const SizedBox(width: 4),
                              Icon(Ph.sealCheckFill,
                                  size: 13, color: pal.act),
                            ],
                          ],
                        ),
                        Text(
                            '${kTraders[i].$3} \u00B7 ${kTraders[i].$6} followers',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 11, color: pal.mute)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('+${kTraders[i].$5.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: pal.gain,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          )),
                      Text('this year',
                          style: TextStyle(fontSize: 10, color: pal.mute)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── AI assistant ─────────────────────────────────────────────────────────

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _input = TextEditingController();
  final List<(bool fromAi, String text)> _chat = [
    (true, 'Ask me about your portfolio, a holding, or how something works.'),
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _chat.add((false, t));
      _chat.add((
        true,
        'This build does not have an assistant wired up yet. Connect it to '
            'your own model endpoint before release \u2014 and keep portfolio '
            'figures server-side rather than in the prompt.'
      ));
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: Column(
        children: [
          const PushedHeader(
              title: 'AI assistant', subtitle: 'Ask about your portfolio'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                for (final m in _chat)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: m.$1
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.$1) ...[
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: pal.ink, shape: BoxShape.circle),
                            child: const Text('X',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            constraints:
                                const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: m.$1 ? pal.p1 : pal.act,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(m.$1 ? 6 : 16),
                                topRight: Radius.circular(m.$1 ? 16 : 6),
                                bottomLeft: const Radius.circular(16),
                                bottomRight: const Radius.circular(16),
                              ),
                            ),
                            child: Text(
                              m.$2,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: m.$1 ? pal.ink : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: pal.p2,
              border: Border(top: BorderSide(color: pal.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(fontSize: 14, color: pal.ink),
                        decoration: InputDecoration(
                          hintText: 'Ask about your portfolio',
                          hintStyle:
                              TextStyle(fontSize: 14, color: pal.mute),
                          filled: true,
                          fillColor: pal.p1,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: pal.act,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Ph.play,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Borrow and finance (Lending) ─────────────────────────────────────────

class LendingScreen extends StatelessWidget {
  const LendingScreen({super.key, required this.money, this.api});

  final Money money;
  final Api? api;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Borrow and finance',
              subtitle: 'Lend against holdings you already own'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('How it works',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: pal.ink,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          'Borrow against your portfolio without selling. '
                          'Your holdings stay invested and keep earning. '
                          'Interest accrues daily and is settled before principal.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: pal.mute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _label(context, 'Advance rates by asset class'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final r in _advanceRates)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border(
                              top: r == _advanceRates.first
                                  ? BorderSide.none
                                  : BorderSide(color: pal.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: pal.tint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(r.$3, size: 17, color: pal.actDk),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(r.$1,
                                    style: TextStyle(
                                      fontSize: 13.5, color: pal.ink,
                                    )),
                              ),
                              Text('${r.$2}% advance',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: pal.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  )),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Margin call at 80% loan-to-value. Liquidation at 90%, '
                  'with three days to put it right. You get a notification '
                  'before either threshold is reached.',
                  style: TextStyle(
                    fontSize: 11.5, height: 1.375, color: pal.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<(String, int, IconData)> _advanceRates = [
  ('Treasury bills', 90, Ph.receipt),
  ('Government funds', 80, Ph.chartPieSlice),
  ('Equity funds', 70, Ph.chartBar),
  ('Metal funds', 60, Ph.coins),
  ('Individual shares', 50, Ph.trendUp),
];

// ── Contact us ───────────────────────────────────────────────────────────

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Contact us', subtitle: 'Chat, message or call'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _contactRows.length; i++)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border(
                              top: i == 0
                                  ? BorderSide.none
                                  : BorderSide(color: pal.line),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: pal.tint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_contactRows[i].$1, size: 19, color: pal.actDk),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_contactRows[i].$2,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: pal.ink,
                                        )),
                                    Text(_contactRows[i].$3,
                                        style: TextStyle(
                                          fontSize: 11, color: pal.mute,
                                        )),
                                  ],
                                ),
                              ),
                              Icon(Ph.caretRight, size: 14, color: pal.mute),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Our team is available Sunday through Thursday, '
                  '9am to 5pm Cairo time. Average first response is '
                  'under 2 hours during market hours.',
                  style: TextStyle(
                    fontSize: 11.5, height: 1.375, color: pal.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final List<(IconData, String, String)> _contactRows = [
  (Ph.chatCircle, 'Live chat', 'Usually answers in under 5 minutes'),
  (Ph.envelope, 'Send a message', 'We reply within 2 hours'),
  (Ph.phone, 'Book a call', 'Pick a time that works for you'),
  (Ph.info, 'FAQs', 'Common questions answered'),
];
