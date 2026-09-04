// My cards — `[data-scr="cards"]`, cardArt(), paintCardPanels(), limitRow().
//
// Now calls api.myCards(), api.setCardControl(), and api.issueCard() rather
// than serving hardcoded mock data.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/api.dart';
import '../widgets/atoms.dart';

/// A card as the API returns it.
class PayCard {
  PayCard({
    required this.id,
    required this.kind,
    required this.name,
    required this.brand,
    required this.last4,
    required this.exp,
    required this.frozen,
    required this.controls,
    required this.monthUsed,
    required this.monthCap,
    required this.txCap,
    required this.atmUsed,
    required this.atmCap,
    required this.state,
  });

  final String id;
  final String kind; // Physical | Virtual
  final String name;
  final String brand;
  final String last4;
  final String exp;
  bool frozen;
  Map<String, bool> controls;
  final num monthUsed;
  final num monthCap;
  final num txCap;
  final num atmUsed;
  final num atmCap;
  final String state; // active | frozen | expired | blocked | ...

  factory PayCard.fromJson(Map<String, dynamic> j) {
    final controlsRaw = j['controls'] as Map? ?? const {};
    final controls = <String, bool>{};
    controlsRaw.forEach((k, v) => controls[k.toString()] = v == true);
    return PayCard(
      id: j['id']?.toString() ?? '',
      kind: j['kind']?.toString() ?? 'Virtual',
      name: j['name']?.toString() ?? '',
      brand: j['brand']?.toString() ?? '',
      last4: j['last4']?.toString() ?? '0000',
      exp: j['exp']?.toString() ?? '',
      frozen: j['frozen'] == true,
      controls: controls,
      monthUsed: _n(j['monthUsed']),
      monthCap: _n(j['monthCap']),
      txCap: _n(j['txCap']),
      atmUsed: _n(j['atmUsed']),
      atmCap: _n(j['atmCap']),
      state: j['state']?.toString() ?? 'active',
    );
  }

  static num _n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
}

class CardsScreen extends StatefulWidget {
  const CardsScreen({
    super.key,
    required this.money,
    required this.api,
    this.onChanged,
  });

  final Money money;
  final Api api;
  final VoidCallback? onChanged;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  List<PayCard> _cards = const [];
  bool _loading = true;
  int _sel = 0;
  bool _revealed = false;
  bool _busy = false;

  PayCard get _c => _cards.isNotEmpty ? _cards[_sel % _cards.length] : _placeholder;
  static final _placeholder = PayCard(
    id: '', kind: 'Virtual', name: 'No cards yet', brand: '',
    last4: '0000', exp: '', frozen: false, controls: const {},
    monthUsed: 0, monthCap: 0, txCap: 0, atmUsed: 0, atmCap: 0,
    state: 'active',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.myCards();
      if (mounted) {
        setState(() {
          _cards = rows
              .whereType<Map>()
              .map((e) => PayCard.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _loading = false;
          if (_sel >= _cards.length) _sel = 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleControl(String key, bool value) async {
    if (_cards.isEmpty) return;
    try {
      await widget.api.setCardControl(_c.id, key, value);
      if (mounted) setState(() => _c.controls[key] = value);
    } catch (_) {
      // Revert on failure.
      if (mounted) setState(() => _c.controls[key] = !value);
    }
  }

  Future<void> _toggleFreeze() async {
    if (_cards.isEmpty) return;
    final next = !_c.frozen;
    try {
      await widget.api.setCardControl(_c.id, 'frozen', next);
      if (mounted) setState(() => _c.frozen = next);
    } catch (_) {
      if (mounted) setState(() => _c.frozen = !next);
    }
  }

  Future<void> _issueCard(String kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await widget.api.issueCard(kind);
      widget.onChanged?.call();
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(kind == 'Physical'
            ? 'Physical card requested. It will arrive in 3 working days.'
            : 'Virtual card issued. It is ready to use.'),
      ));
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not issue card.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      bottomNavigationBar: _buildBottomBar(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Ph.creditCard, size: 40, color: pal.mute),
                      const SizedBox(height: 12),
                      Text('No cards yet',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: pal.ink,
                          )),
                      const SizedBox(height: 6),
                      Text('Issue your first card below.',
                          style: TextStyle(fontSize: 12.5, color: pal.mute)),
                    ],
                  ),
                )
              : ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: pal.p1, shape: BoxShape.circle),
                      child: Icon(Ph.caretLeft, size: 15, color: pal.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('My cards',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                ],
              ),
            ),
          ),
          _carousel(context),
          const SizedBox(height: 12),
          _dots(context),
          _actions(context),
          const SizedBox(height: 8),
          _panel(context, 'Card details', _details(context)),
          _panel(context, 'Spending limits', _limits(context),
              action: 'Edit'),
          _panel(context, 'Controls', _controls(context)),
          _panel(context, 'Issue a new card', _issue(context)),
          _panel(context, 'Recent card activity', _activity(context)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, String title, Widget child,
      {String? action}) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: pal.ink,
                    )),
              ),
              if (action != null)
                Text(action,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: pal.actDk,
                    )),
            ],
          ),
          child,
        ],
      ),
    );
  }

  // ── the card faces ──────────────────────────────────────────────────────

  Widget _carousel(BuildContext context) => SizedBox(
        height: 158,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _face(context, _cards[i], i),
        ),
      );

  Widget _face(BuildContext context, PayCard c, int i) {
    final pal = context.pal;
    final bg = c.kind == 'Physical' ? pal.ink : pal.act;
    return GestureDetector(
      onTap: () => setState(() {
        _sel = i;
        _revealed = false;
      }),
      child: Container(
        width: 258,
        height: 158,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: i == _sel
              ? Border.all(color: pal.act, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c.kind,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: .80),
                        )),
                    if (c.frozen)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Ph.snowflake,
                                size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                            const Text('Frozen',
                                style: TextStyle(
                                    fontSize: 10.5, color: Colors.white)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )),
              ],
            ),
            // The chip.
            Positioned(
              left: 0,
              bottom: 46,
              child: Container(
                width: 36,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Text(
                '\u2022\u2022\u2022\u2022 ${c.last4}',
                style: const TextStyle(
                  fontSize: 15,
                  letterSpacing: 2,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 2,
              child: Text(c.brand,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: .80),
                  )),
            ),
            if (c.frozen)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                      color: Colors.white.withValues(alpha: .16)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dots(BuildContext context) {
    final pal = context.pal;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _cards.length; i++) ...[
          Opacity(
            opacity: i == _sel ? .85 : .25,
            child: Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: pal.mute, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  // ── actions ─────────────────────────────────────────────────────────────

  Widget _actions(BuildContext context) {
    final pal = context.pal;
    final acts = [
      (_c.frozen ? Ph.play : Ph.snowflake, _c.frozen ? 'Unfreeze' : 'Freeze',
          'freeze'),
      (Ph.eye, 'Details', 'details'),
      (Ph.password, 'PIN', 'pin'),
      (Ph.arrowsClockwise, 'Replace', 'replace'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Row(
        children: [
          for (final a in acts)
            Expanded(
              child: GestureDetector(
                onTap: () => _act(a.$3),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pal.tint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(a.$1, size: 21, color: pal.actDk),
                    ),
                    const SizedBox(height: 6),
                    Text(a.$2,
                        style: TextStyle(fontSize: 11, color: pal.mute)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _act(String k) {
    switch (k) {
      case 'freeze':
        _toggleFreeze();
      case 'details':
        _confirmThen(() => setState(() => _revealed = true));
      case 'pin':
        _confirmThen(_showPin);
      case 'replace':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A replacement card has been ordered.')),
        );
    }
  }

  /// The PWA's "confirm it's you" step accepts any tap, which its own README
  /// flags as unacceptable before launch. This asks for the device's own
  /// authentication instead of pretending — until that is wired to real
  /// biometrics, it is at least explicit that nothing has been verified.
  void _confirmThen(VoidCallback then) {
    final pal = context.pal;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.p2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(Ph.fingerprint, size: 40, color: pal.actDk),
              ),
              const SizedBox(height: 12),
              Text('Confirm it\u2019s you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: pal.ink,
                  )),
              const SizedBox(height: 6),
              Text(
                'Card details and PIN need authentication. This build does not '
                'yet verify anything \u2014 wire it to device biometrics before '
                'release.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.5, color: pal.mute),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.of(sheet).pop();
                  then();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.act,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
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

  void _showPin() {
    final pal = context.pal;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.p2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Your PIN',
                  style: TextStyle(fontSize: 12, color: pal.mute)),
              const SizedBox(height: 12),
              Text('PIN is not stored on this server.\n'
                  'Contact support if you need to reset it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: pal.mute)),
            ],
          ),
        ),
      ),
    );
  }

  // ── panels ──────────────────────────────────────────────────────────────

  Widget _details(BuildContext context) {
    final rows = [
      ('Card number', '\u2022\u2022\u2022\u2022 \u2022\u2022\u2022\u2022 \u2022\u2022\u2022\u2022 ${_c.last4}'),
      ('Expiry', _c.exp),
      ('Network', _c.brand),
      ('Type', _c.kind),
      ('Status', _c.state),
    ];
    final pal = context.pal;
    return Column(
      children: [
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: pal.line)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.$1, style: TextStyle(fontSize: 13, color: pal.mute)),
                Text(r.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: pal.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ],
            ),
          ),
      ],
    );
  }

  Widget _limits(BuildContext context) => Column(
        children: [
          _limitRow(context, 'Monthly spend', _c.monthUsed, _c.monthCap),
          _limitRow(context, 'Per transaction', 0, _c.txCap),
          _limitRow(context, 'ATM withdrawals', _c.atmUsed, _c.atmCap),
        ],
      );

  Widget _limitRow(BuildContext context, String label, num used, num cap) {
    final pal = context.pal;
    final pc = cap == 0 ? 0.0 : (used / cap).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: pal.ink)),
              Text(
                cap == 0
                    ? 'Not available'
                    : '${widget.money.format(used)} / '
                        '${widget.money.format(cap)} ${widget.money.code}',
                style: TextStyle(
                  fontSize: 12,
                  color: pal.mute,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (cap != 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pc,
                minHeight: 3,
                backgroundColor: pal.p1,
                valueColor: AlwaysStoppedAnimation(pal.act),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _controls(BuildContext context) {
    final pal = context.pal;
    const items = [
      ('online', 'Online payments', Ph.globe),
      ('contactless', 'Contactless', Ph.wifiHigh),
      ('intl', 'International use', Ph.airplaneTilt),
      ('atm', 'ATM withdrawals', Ph.money),
    ];
    return Column(
      children: [
        for (final it in items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: pal.line)),
            ),
            child: Row(
              children: [
                Icon(it.$3, size: 18, color: pal.mute),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(it.$2,
                      style: TextStyle(fontSize: 13, color: pal.ink)),
                ),
                // Resolved through WidgetStateProperty rather than
                // activeColor / activeThumbColor, which have swapped names
                // across Flutter versions.
                Switch(
                  value: _c.controls[it.$1] ?? false,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : pal.p2,
                  ),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? pal.act
                        : pal.p1,
                  ),
                  onChanged: _cards.isEmpty
                      ? null
                      : (v) => _toggleControl(it.$1, v),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _issue(BuildContext context) {
    final pal = context.pal;
    const tiles = [
      ('Physical card', 'Delivered in 3 days', Ph.creditCard, 'Physical'),
      ('Virtual card', 'Ready instantly', Ph.deviceMobile, 'Virtual'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _busy ? null : () => _issueCard(tiles[i].$4),
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: _busy ? 0.5 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pal.p1,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.tint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(tiles[i].$3, size: 20, color: pal.actDk),
                        ),
                        const SizedBox(height: 8),
                        Text(tiles[i].$1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: pal.ink,
                            )),
                        Text(tiles[i].$2,
                            style: TextStyle(fontSize: 11, color: pal.mute)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activity(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: pal.p1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text('No card transactions yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: pal.mute)),
      ),
    );
  }

  /// Bottom bar matching the Shell's tab bar so navigation context is kept.
  Widget _buildBottomBar(BuildContext context) {
    final pal = context.pal;
    final tabs = [
      (Ph.house, 'Home'),
      (Ph.magnifyingGlass, 'Discover'),
      (Ph.chartLine, 'Markets'),
      (Ph.wallet, 'Money'),
      (Ph.gear, 'Settings'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: pal.p2,
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final t in tabs)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$1,
                          size: 20,
                          color: t.$2 == 'Money' ? pal.act : pal.mute),
                      const SizedBox(height: 3),
                      Text(t.$2,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: t.$2 == 'Money' ? pal.actDk : pal.mute,
                          )),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
