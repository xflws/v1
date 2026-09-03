// The last of the settings sub-screens: price alerts, statements, reports,
// sub-accounts, family accounts and legal documents.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../widgets/atoms.dart';
import '../widgets/holdings.dart' show tickerColour;
import 'more_screens.dart' show PushedHeader;
import '../data/api.dart';

Widget _cap(BuildContext context, String s, {double top = 16}) => Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 4),
      child: Text(s, style: TextStyle(fontSize: 12, color: context.pal.mute)),
    );

/// The dashed "add" row used by alerts and sub-accounts.
class DashedAddRow extends StatelessWidget {
  const DashedAddRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Ph.plus,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 12),
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
            child: Icon(icon, size: 18, color: pal.act),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: pal.ink,
                    )),
                Text(subtitle,
                    style: TextStyle(fontSize: 11, color: pal.mute)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A generic row: tinted icon tile, title over subtitle, optional trailing.
class IconRow extends StatelessWidget {
  const IconRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.first = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool first;
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
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: pal.actDk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: pal.ink,
                      )),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: pal.mute)),
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

Widget _scaffold(BuildContext context, String title, String subtitle,
        List<Widget> children) =>
    Scaffold(
      backgroundColor: context.pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          PushedHeader(title: title, subtitle: subtitle),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );

// ── Price alerts ─────────────────────────────────────────────────────────

const List<(String, String, num, String)> kAlerts = [
  ('CLHO', 'above', 18.50, 'Take some off the table'),
  ('CPME', 'below', 18.00, ''),
  ('GLD', 'above', 7000, 'Trim gold'),
];

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.money, this.api});

  final Money money;
  final Api? api;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  /// (id, ticker, direction, price, note)
  List<(String, String, String, num, String)> _rows = const [];
  bool _loaded = false;

  Money get money => widget.money;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Live alerts when the deployment serves them; the seeded examples
  /// otherwise, so the screen is never blank on a fresh install.
  Future<void> _load() async {
    final api = widget.api;
    if (api == null) return;
    try {
      final rows = await api.alerts();
      if (!mounted) return;
      setState(() {
        _rows = rows
            .whereType<Map>()
            .map((e) => (
                  '${e['id'] ?? ''}',
                  '${e['ticker'] ?? ''}',
                  '${e['direction'] ?? 'above'}',
                  (e['price'] is num ? e['price'] as num : 0),
                  '${e['note'] ?? ''}',
                ))
            .toList();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _delete(int i) async {
    final id = _rows[i].$1;
    final api = widget.api;
    if (api == null || id.isEmpty) {
      if (mounted) setState(() => _rows.removeAt(i));
      return;
    }
    try {
      await api.deleteAlert(id);
      if (mounted) setState(() => _rows.removeAt(i));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete alert.')),
      );
    }
  }

  void _create() {
    if (widget.api == null) return;
    final tickerCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String direction = 'above';
    final pal = context.pal;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: pal.p2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setS) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
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
                Text('New price alert',
                    style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600,
                      color: pal.ink,
                    )),
                const SizedBox(height: 12),
                TextField(
                  controller: tickerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ticker', hintText: 'e.g. CLHO',
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(fontSize: 14, color: pal.ink),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: const Text('Rises above'),
                        value: 'above', groupValue: direction,
                        onChanged: (v) => setS(() => direction = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: const Text('Falls below'),
                        value: 'below', groupValue: direction,
                        onChanged: (v) => setS(() => direction = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Price', border: OutlineInputBorder(),
                  ),
                  style: TextStyle(fontSize: 14, color: pal.ink),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final t = tickerCtrl.text.trim().toUpperCase();
                    final p = num.tryParse(priceCtrl.text);
                    if (t.isEmpty || p == null || p <= 0) return;
                    try {
                      await widget.api!.saveAlert(
                        ticker: t, direction: direction, price: p);
                      if (mounted) {
                        Navigator.of(sheet).pop();
                        await _load();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Alert set on $t'),
                        ));
                      }
                    } on ApiException catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Could not save alert.')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.act,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Set alert',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return _scaffold(context, 'Price alerts', 'Tell me when something moves', [
      if (!_loaded)
        const Center(child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ))
      else if (_rows.isEmpty)
        Column(children: [
          const EmptyState(
            icon: Ph.bell,
            title: 'No alerts yet',
            body: 'Set one on any instrument and it will notify you.',
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _create,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: pal.line, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.tint, shape: BoxShape.circle),
                    child: Icon(Ph.bell, size: 18, color: pal.act),
                  ),
                  const SizedBox(width: 12),
                  Text('New price alert',
                      style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w500,
                        color: pal.ink,
                      )),
                ],
              ),
            ),
          ),
        ])
      else
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < _rows.length; i++)
                Dismissible(
                  key: ValueKey(_rows[i].$1 + _rows[i].$2),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: pal.loss,
                    child: Icon(Ph.trash, color: Colors.white, size: 18),
                  ),
                  onDismissed: (_) => _delete(i),
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
                        Mark(
                          monogram: _rows[i].$2.substring(0, 2),
                          colour: tickerColour(_rows[i].$2),
                          ticker: _rows[i].$2,
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_rows[i].$2} '
                                '${_rows[i].$3 == 'above' ? 'rises above' : 'falls below'} '
                                '${money.format(_rows[i].$4, decimals: 2)}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: pal.ink,
                                ),
                              ),
                              if (_rows[i].$5.isNotEmpty)
                                Text(_rows[i].$5,
                                    style: TextStyle(
                                        fontSize: 11, color: pal.mute)),
                            ],
                          ),
                        ),
                        Icon(
                          _rows[i].$3 == 'above' ? Ph.trendUp : Ph.trendDown,
                          size: 16,
                          color: _rows[i].$3 == 'above' ? pal.gain : pal.loss,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      if (_rows.isNotEmpty) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _create,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pal.line, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.tint, shape: BoxShape.circle),
                  child: Icon(Ph.bell, size: 18, color: pal.act),
                ),
                const SizedBox(width: 12),
                Text('New price alert',
                    style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w500,
                      color: pal.ink,
                    )),
              ],
            ),
          ),
        ),
      ],
    ]);
  }
}

// ── Statement ────────────────────────────────────────────────────────────

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  String _period = 'This month';
  String _type = 'email';

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const periods = [
      'This month',
      'Last quarter',
      'Year to date',
      'Custom range'
    ];

    return Scaffold(
      backgroundColor: pal.p0,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const PushedHeader(
                    title: 'Request a statement',
                    subtitle: 'Email or certified copy'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _cap(context, 'Period'),
                      InnerCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < periods.length; i++)
                              InkWell(
                                onTap: () =>
                                    setState(() => _period = periods[i]),
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
                                      Expanded(
                                        child: Text(periods[i],
                                            style: TextStyle(
                                                fontSize: 13.5,
                                                color: pal.ink)),
                                      ),
                                      if (periods[i] == _period)
                                        Icon(Ph.check,
                                            size: 16, color: pal.act),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _cap(context, 'Type'),
                      InnerCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            IconRow(
                              icon: Ph.envelope,
                              title: 'Email statement',
                              subtitle:
                                  'Sent to a\u2022\u2022\u2022@gmail.com \u00B7 free \u00B7 instant',
                              first: true,
                              trailing: _type == 'email'
                                  ? Icon(Ph.check, size: 16, color: pal.act)
                                  : null,
                              onTap: () => setState(() => _type = 'email'),
                            ),
                            IconRow(
                              icon: Ph.certificate,
                              title: 'Certified statement',
                              subtitle:
                                  'Stamped and signed for visas or banks \u00B7 150 EGP \u00B7 2 days',
                              trailing: _type == 'verified'
                                  ? Icon(Ph.check, size: 16, color: pal.act)
                                  : null,
                              onTap: () => setState(() => _type = 'verified'),
                            ),
                          ],
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('$_period statement requested.')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.act,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Request statement',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        )),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reports ──────────────────────────────────────────────────────────────

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.money});

  final Money money;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const rows = [
      (Ph.chartLine, 'Performance report',
          'Returns by asset class and period'),
      (Ph.receipt, 'Tax report', 'Realised gains and dividends for 2026'),
      (Ph.listChecks, 'Activity report', 'Every order and transfer'),
      (Ph.percent, 'Fees and commission', 'What you paid and to whom'),
    ];

    return _scaffold(context, 'Reports', 'Download what you need', [
      InnerCard(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Return this year',
                  style: TextStyle(fontSize: 11, color: pal.mute)),
              const SizedBox(height: 4),
              Text('+14.２%'.replaceAll('２', '2'),
                  style: TextStyle(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: pal.gain,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              const SizedBox(height: 8),
              // Time-weighted, because a single percentage is wrong the
              // moment money enters or leaves the account.
              Text(
                'Time-weighted, so deposits and withdrawals do not distort it. '
                'Compare this against an index rather than against a naive '
                'gain figure.',
                style: TextStyle(
                    fontSize: 11.5, height: 1.375, color: pal.mute),
              ),
            ],
          ),
        ),
      ),
      _cap(context, 'Download'),
      InnerCard(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              IconRow(
                icon: rows[i].$1,
                title: rows[i].$2,
                subtitle: rows[i].$3,
                first: i == 0,
                trailing:
                    Icon(Ph.downloadSimple, size: 16, color: pal.mute),
              ),
          ],
        ),
      ),
    ]);
  }
}

// ── Sub-accounts ─────────────────────────────────────────────────────────

const List<(String, num, num, int, bool, IconData)> kSubs = [
  ('Long-term core', 312000, 400000, 25, false, Ph.tree),
  ('Trading pot', 48000, 60000, 15, false, Ph.lightning),
  ('Hajj savings', 42000, 250000, 5, true, Ph.moonStars),
];

class SubAccountsScreen extends StatelessWidget {
  const SubAccountsScreen({super.key, required this.money});

  final Money money;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return _scaffold(
        context, 'Sub-accounts', 'Separate pots with their own limits', [
      InnerCard(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < kSubs.length; i++)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border(
                    top: i == 0
                        ? BorderSide.none
                        : BorderSide(color: pal.line),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.tint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(kSubs[i].$6,
                              size: 18, color: pal.actDk),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(kSubs[i].$1,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: pal.ink,
                                  )),
                              Text(
                                '${money.format(kSubs[i].$2)} of '
                                '${money.format(kSubs[i].$3)} ${money.code} cap',
                                style: TextStyle(
                                    fontSize: 11, color: pal.mute),
                              ),
                            ],
                          ),
                        ),
                        Pill(
                          text: kSubs[i].$5 ? 'Frozen' : 'Active',
                          tone: kSubs[i].$5
                              ? Tone.mute(context)
                              : Tone.gain(context),
                          icon: kSubs[i].$5 ? Ph.snowflake : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (kSubs[i].$2 / kSubs[i].$3)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        minHeight: 4,
                        backgroundColor: pal.p1,
                        valueColor: AlwaysStoppedAnimation(pal.act),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Stops trading if it falls ${kSubs[i].$4}% in a month',
                        style: TextStyle(fontSize: 11, color: pal.mute),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const DashedAddRow(
          title: 'New sub-account',
          subtitle: 'Its own cap and loss limit'),
    ]);
  }
}

// ── Family accounts ──────────────────────────────────────────────────────

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _scaffold(context, 'Family accounts', 'Joint and junior accounts', [
      _cap(context, 'Your accounts', top: 8),
      InnerCard(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            IconRow(
              icon: Ph.users,
              title: 'Joint with Mona Kamal',
              subtitle: 'Both approve anything above 25,000 EGP',
              first: true,
              trailing: Pill(text: 'Active', tone: Tone.gain(context)),
            ),
            IconRow(
              icon: Ph.baby,
              title: 'Yousef \u00B7 junior account',
              subtitle: 'You control it until he turns 21',
              trailing: Pill(text: 'Active', tone: Tone.gain(context)),
            ),
          ],
        ),
      ),
      const DashedAddRow(
          title: 'Open a joint or junior account',
          subtitle: 'Both holders must verify identity'),
    ]);
  }
}

// ── Legal ────────────────────────────────────────────────────────────────

const List<(String, String, IconData)> kDocs = [
  ('Account opening application', 'Signed 14 Mar 2026', Ph.fileText),
  ('Client agreement', 'Signed 14 Mar 2026', Ph.fileText),
  ('Risk disclosure', 'Signed 14 Mar 2026', Ph.warningCircle),
  ('W-8BEN form', 'Signed 14 Mar 2026', Ph.globe),
  ('National ID copy', 'Uploaded 14 Mar 2026', Ph.identificationCard),
];

const List<(String, String, IconData)> kAgreements = [
  ('Terms of business', 'FRA regulated', Ph.scroll),
  ('Privacy policy', 'How your data is handled', Ph.lock),
  ('Fee schedule', 'Commission, custody and transfer fees', Ph.percent),
  ('Complaints procedure', 'How to escalate', Ph.warningCircle),
];

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return _scaffold(context, 'Legal and documents', 'Agreements and copies', [
      _cap(context, 'My documents', top: 8),
      InnerCard(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < kDocs.length; i++)
              IconRow(
                icon: kDocs[i].$3,
                title: kDocs[i].$1,
                subtitle: kDocs[i].$2,
                first: i == 0,
                trailing:
                    Icon(Ph.downloadSimple, size: 16, color: pal.mute),
              ),
          ],
        ),
      ),
      _cap(context, 'Agreements'),
      InnerCard(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < kAgreements.length; i++)
              IconRow(
                icon: kAgreements[i].$3,
                title: kAgreements[i].$1,
                subtitle: kAgreements[i].$2,
                first: i == 0,
                trailing: Icon(Ph.caretRight, size: 13, color: pal.mute),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'XFLWS is regulated by the Financial Regulatory Authority. Client '
        'money is held with a registered custodian, separately from the '
        'firm\u2019s own funds.',
        style: TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
      ),
    ]);
  }
}
