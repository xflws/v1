// The money flows — `[data-scr="flow"]` and paintFlow() — plus search and
// notifications.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/atoms.dart';
import '../widgets/holdings.dart' show tickerColour;
import '../widgets/open_security.dart';
import 'more_screens.dart' show PushedHeader;

/// FLOWMETA — title, subtitle, amount label and call to action per flow.
const Map<String, (String, String, String, String)> kFlowMeta = {
  'deposit': ('Add money', 'Into your XFLWS wallet', 'Amount to add', 'Add money'),
  'withdraw': ('Withdraw', 'From available cash', 'Amount to withdraw', 'Withdraw'),
  'bill': ('Pay a bill', 'Utilities and services', 'Amount to pay', 'Pay bill'),
};

/// METHODS2 — key, name, terms, icon.
const Map<String, List<(String, String, String, IconData)>> kMethods = {
  'deposit': [
    ('instapay', 'InstaPay', 'Instant \u00B7 free', Ph.deviceMobile),
    ('wallet', 'Mobile wallet',
        'Vodafone Cash, Orange Money and more \u00B7 0.5%', Ph.wallet),
    ('bank', 'Bank transfer', '1 working day \u00B7 free', Ph.bank),
    ('card', 'Debit card', 'Instant \u00B7 1.0% fee', Ph.creditCard),
    ('fawry', 'Fawry cash-in', 'Pay cash at any outlet \u00B7 5 EGP',
        Ph.storefront),
  ],
  'withdraw': [
    ('bank', 'To my bank account',
        'CIB \u2022\u2022\u2022\u20224471 \u00B7 1 working day \u00B7 free', Ph.bank),
    ('instapay', 'InstaPay',
        'Any Egyptian bank \u00B7 instant \u00B7 5 EGP', Ph.deviceMobile),
    ('wallet', 'Mobile wallet',
        'Vodafone Cash, Orange Money and more \u00B7 0.5%', Ph.wallet),
    ('atm', 'Cardless ATM', 'Collect cash with a code \u00B7 10 EGP', Ph.money),
    ('fawry', 'Fawry outlet', 'Collect cash in person \u00B7 10 EGP',
        Ph.storefront),
  ],
};

const List<(IconData, String)> kBillers = [
  (Ph.deviceMobile, 'Mobile'),
  (Ph.broadcast, 'ADSL'),
  (Ph.phone, 'Landline'),
  (Ph.lightning, 'Electricity'),
  (Ph.television, 'TV'),
  (Ph.drop, 'Water'),
  (Ph.graduationCap, 'Tuition'),
  (Ph.car, 'Traffic'),
];

class MoneyFlowScreen extends StatefulWidget {
  const MoneyFlowScreen({
    super.key,
    required this.kind,
    required this.money,
    required this.api,
    this.available = 0,
    this.biller = 'Mobile',
    this.onDone,
  });

  final Api api;

  /// Refreshes the portfolio once the server has answered.
  final VoidCallback? onDone;

  /// deposit | withdraw | bill
  final String kind;
  final Money money;
  final num available;
  final String biller;

  @override
  State<MoneyFlowScreen> createState() => _MoneyFlowScreenState();
}

class _MoneyFlowScreenState extends State<MoneyFlowScreen> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.kind == 'withdraw' ? '500' : '1000');
  final TextEditingController _ref = TextEditingController();
  late String _method =
      (kMethods[widget.kind] ?? const []).isEmpty ? '' : kMethods[widget.kind]!.first.$1;
  late String _biller = widget.biller;
  bool _busy = false;
  String? _error;

  num get _amt => num.tryParse(_amount.text) ?? 0;

  /// A deposit has no ceiling; a withdrawal or a bill cannot exceed what is
  /// actually spendable.
  bool get _over =>
      _amt <= 0 || (widget.kind != 'deposit' && _amt > widget.available);

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final meta = kFlowMeta[widget.kind]!;
    final title = widget.kind == 'bill' ? '$_biller bill' : meta.$1;

    return Scaffold(
      backgroundColor: pal.p0,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                PushedHeader(title: title, subtitle: meta.$2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _amountCard(context, meta.$3),
                      _quick(context),
                      if (widget.kind == 'bill') ...[
                        _cap(context, 'Biller'),
                        _billerList(context),
                        _cap(context, 'Account number'),
                        _field(context, _ref, 'e.g. 0100 123 4567'),
                      ] else ...[
                        _cap(context,
                            widget.kind == 'deposit' ? 'Pay with' : 'Send to'),
                        _methodList(context),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Row(
                            children: [
                              Icon(Ph.warningCircle,
                                  size: 14, color: context.pal.loss),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(_error!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.pal.loss)),
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
          _footer(context, meta.$4),
        ],
      ),
    );
  }

  Widget _cap(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(s,
            style: TextStyle(fontSize: 12, color: context.pal.mute)),
      );

  Widget _amountCard(BuildContext context, String label) {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.p2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: pal.mute)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(widget.money.code,
                  style: TextStyle(fontSize: 15, color: pal.mute)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.kind == 'deposit'
                ? 'No limit on deposits'
                : 'Available ${widget.money.format(widget.available, decimals: 2)} '
                    '${widget.money.code}',
            style: TextStyle(
              fontSize: 11,
              color: _over && _amt > 0 ? pal.loss : pal.mute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quick(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(
                    () => _amount.text = '${[100, 500, 1000, 5000][i]}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.p1,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${[100, 500, 1000, 5000][i]}',
                      style: TextStyle(fontSize: 12, color: pal.ink)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _methodList(BuildContext context) {
    final pal = context.pal;
    final opts = kMethods[widget.kind] ?? const [];
    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < opts.length; i++)
            InkWell(
              onTap: () => setState(() => _method = opts[i].$1),
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
                        color: _method == opts[i].$1 ? pal.tint : pal.p1,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(opts[i].$4,
                          size: 18,
                          color: _method == opts[i].$1
                              ? pal.actDk
                              : pal.mute),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opts[i].$2,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: pal.ink,
                              )),
                          Text(opts[i].$3,
                              style: TextStyle(
                                  fontSize: 11, color: pal.mute)),
                        ],
                      ),
                    ),
                    if (_method == opts[i].$1)
                      Icon(Ph.check, size: 16, color: pal.act),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _billerList(BuildContext context) {
    final pal = context.pal;
    return InnerCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < kBillers.length; i++)
            InkWell(
              onTap: () => setState(() => _biller = kBillers[i].$2),
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
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _biller == kBillers[i].$2 ? pal.tint : pal.p1,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(kBillers[i].$1,
                          size: 17,
                          color: _biller == kBillers[i].$2
                              ? pal.actDk
                              : pal.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(kBillers[i].$2,
                          style: TextStyle(
                              fontSize: 13.5, color: pal.ink)),
                    ),
                    if (_biller == kBillers[i].$2)
                      Icon(Ph.check, size: 16, color: pal.act),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
      BuildContext context, TextEditingController c, String hint) {
    final pal = context.pal;
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 14, color: pal.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: pal.mute),
        filled: true,
        fillColor: pal.p2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pal.act, width: 1.5),
        ),
      ),
    );
  }

  /// Posts to the API. The server decides whether it settles now, waits for a
  /// simulated provider, or goes to a person; the message reflects which.
  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      late Map<String, dynamic> r;
      switch (widget.kind) {
        case 'deposit':
          r = await widget.api.deposit(_amt, _method);
        case 'withdraw':
          r = await widget.api.withdraw(_amt, _method);
        default:
          r = await widget.api.payBill(
              amount: _amt, biller: _biller, reference: _ref.text.trim());
      }
      final status = '${(r['transaction'] as Map?)?['status'] ?? 'pending'}';
      widget.onDone?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'settled'
            ? '${widget.money.format(_amt, decimals: 2)} ${widget.money.code} done.'
            : 'Requested. We will confirm once it clears.'),
      ));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _footer(BuildContext context, String cta) {
    final pal = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: pal.p2,
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: GestureDetector(
            onTap: (_over || _busy) ? null : _submit,
            child: Opacity(
              opacity: (_over || _busy) ? .45 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pal.act,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(cta,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        )),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search ───────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.api,
    required this.money,
    this.available = 0,
    this.initialQuery = '',
  });

  final Api api;
  final Money money;
  final num available;
  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _q =
      TextEditingController(text: widget.initialQuery);
  List<Instrument> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.instruments();
      if (mounted) {
        setState(() {
          _all = rows
              .whereType<Map>()
              .map((e) => Instrument.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Instrument> get _results {
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) return _all.take(20).toList();
    return _all
        .where((i) =>
            i.ticker.toLowerCase().contains(q) ||
            i.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final rows = _results;

    return Scaffold(
      backgroundColor: pal.p0,
      body: Column(
        children: [
          SafeArea(
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
                      decoration: BoxDecoration(
                          color: pal.p1, shape: BoxShape.circle),
                      child:
                          Icon(Ph.caretLeft, size: 15, color: pal.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _q,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(fontSize: 14, color: pal.ink),
                      decoration: InputDecoration(
                        hintText: 'Search stocks and funds',
                        hintStyle:
                            TextStyle(fontSize: 14, color: pal.mute),
                        prefixIcon: Icon(Ph.magnifyingGlass,
                            size: 16, color: pal.mute),
                        filled: true,
                        fillColor: pal.p1,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? EmptyState(
                        icon: Ph.magnifyingGlass,
                        title: 'Nothing found',
                        body: 'Try a ticker like CLHO, or a company name.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: rows.length,
                        itemBuilder: (context, i) => InkWell(
                          onTap: () => openSecurity(
                            context,
                            api: widget.api,
                            money: widget.money,
                            instrument: rows[i],
                            available: widget.available,
                          ),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: pal.line),
                              ),
                            ),
                            child: Row(
                              children: [
                                Mark(
                                  monogram: rows[i].ticker.substring(
                                      0, rows[i].ticker.length.clamp(0, 2)),
                                  colour: tickerColour(rows[i].ticker),
                                  ticker: rows[i].ticker,
                                  size: 36,
                                  logoUrl: widget.api.logoUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(rows[i].ticker,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            color: pal.ink,
                                          )),
                                      Text(rows[i].name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: pal.mute)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      widget.money
                                          .format(rows[i].last, decimals: 2),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: pal.ink,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    PctTag(
                                        delta: rows[i].change,
                                        up: rows[i].up),
                                  ],
                                ),
                              ],
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

// ── Notifications ────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});

  final Api api;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.myNotifications();
      if (mounted) {
        setState(() {
          _rows = r
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      }
      // Opening the list is what marks them read.
      await widget.api.markNotificationsRead();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
              title: 'Notifications', subtitle: 'Alerts, orders and messages'),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rows.isEmpty)
            const EmptyState(
              icon: Ph.bell,
              title: 'Nothing new',
              body: 'Price alerts, order fills and messages appear here.',
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: InnerCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _rows.length; i++)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          // Unread rows carry a faint accent wash rather than
                          // a dot, which is easier to scan down a list.
                          color: _rows[i]['read'] == true
                              ? null
                              : pal.tint.withValues(alpha: .5),
                          border: Border(
                            top: i == 0
                                ? BorderSide.none
                                : BorderSide(color: pal.line),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: pal.tint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Ph.bell,
                                  size: 17, color: pal.actDk),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('${_rows[i]['title'] ?? 'Notice'}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: pal.ink,
                                      )),
                                  if (_rows[i]['body'] != null)
                                    Text('${_rows[i]['body']}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.4,
                                          color: pal.mute,
                                        )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
