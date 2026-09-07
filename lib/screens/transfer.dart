// Transfer — `[data-scr="xfer"]` and paintXfer().
//
// Four steps: Recipient, Confirm, Amount, Review. The confirm step exists on
// purpose — transfers are instant and irreversible, so the name is shown
// before the amount is ever entered.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../widgets/atoms.dart';
import '../widgets/holdings.dart' show tickerColour;
import '../data/api.dart';

const List<String> kXferSteps = ['Recipient', 'Confirm', 'Amount', 'Review'];

class Recipient {
  Recipient({
    required this.handle,
    required this.name,
    this.email = '',
    this.since = '',
  });

  final String handle;
  final String name;
  final String email;
  final String since;

  factory Recipient.fromJson(Map<String, dynamic> j) => Recipient(
    handle: j['handle'] ?? '',
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    since: (j['since'] ?? '').toString().substring(0, 4),
  );
}

class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    required this.money,
    required this.api,
    this.available = 0,
    this.onDone,
  });

  final Money money;
  final Api api;
  final num available;
  final VoidCallback? onDone;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  int _step = 0;
  String _method = 'qr';
  Recipient? _to;
  final _searchCtrl = TextEditingController();
  List<Recipient> _results = const [];
  bool _searching = false;
  final TextEditingController _query = TextEditingController();
  final TextEditingController _amount = TextEditingController(text: '1000');
  final TextEditingController _note = TextEditingController();

  num get _amt => num.tryParse(_amount.text) ?? 0;
  bool get _over => _amt > widget.available || _amt <= 0;

  @override
  void dispose() {
    _query.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Recipient? _find() {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return null;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    for (final r in _results) {
      if (r.handle.toLowerCase() == q ||
          r.name.toLowerCase() == q ||
          r.email.toLowerCase() == q ||
          (digits.isNotEmpty && r.handle.contains(digits))) {
        return r;
      }
    }
    return null;
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final rows = await widget.api.searchUsers(q.trim());
      if (mounted) {
        setState(() =>
            _results = rows
                .whereType<Map>()
                .map((e) => Recipient.fromJson(Map<String, dynamic>.from(e)))
                .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [_body(context)],
            ),
          ),
          if (_step > 0) _footer(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final pal = context.pal;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_step == 0) {
                      Navigator.of(context).maybePop();
                    } else {
                      setState(() {
                        _step--;
                        if (_step < 1) _to = null;
                      });
                    }
                  },
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
                      Text('Transfer',
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: pal.ink,
                          )),
                      Text(
                        'Step ${_step + 1} of ${kXferSteps.length} \u00B7 '
                        '${kXferSteps[_step]}',
                        style: TextStyle(fontSize: 11.5, color: pal.mute),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < kXferSteps.length; i++) ...[
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step ? pal.act : pal.p1,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  if (i < kXferSteps.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) => switch (_step) {
        0 => _stepRecipient(context),
        1 => _stepConfirm(context),
        2 => _stepAmount(context),
        _ => _stepReview(context),
      };

  // ── step 0 ──────────────────────────────────────────────────────────────

  Widget _stepRecipient(BuildContext context) {
    final pal = context.pal;
    const ways = [
      ('qr', 'Scan QR code', 'The recipient shows their code', Ph.qrCode, true),
      ('handle', 'XFLWS handle', 'Like @mona.k', Ph.user, false),
      ('phone', 'Phone number', 'Registered mobile', Ph.deviceMobile, false),
      ('email', 'Email address', 'Registered email', Ph.envelope, false),
    ];
    final recent = _results.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, 'How do you want to find them?'),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < ways.length; i++)
                InkWell(
                  onTap: () => setState(() {
                    _method = ways[i].$1;
                    _step = 1;
                  }),
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
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _method == ways[i].$1 ? pal.tint : pal.p1,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(ways[i].$4,
                              size: 19,
                              color: _method == ways[i].$1
                                  ? pal.actDk
                                  : pal.mute),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(ways[i].$2,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: pal.ink,
                                      )),
                                  if (ways[i].$5) ...[
                                    const SizedBox(width: 8),
                                    Pill(
                                      text: 'safest',
                                      tone: Tone.gain(context),
                                      icon: Ph.shieldCheck,
                                    ),
                                  ],
                                ],
                              ),
                              Text(ways[i].$3,
                                  style: TextStyle(
                                      fontSize: 11, color: pal.mute)),
                            ],
                          ),
                        ),
                        Icon(Ph.caretRight, size: 13, color: pal.mute),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.line, width: 2),
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
                child: Icon(Ph.qrCode, size: 19, color: pal.act),
              ),
              const SizedBox(width: 12),
              Text('Show my QR code',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: pal.ink,
                  )),
            ],
          ),
        ),
        if (recent.isNotEmpty) ...[
          _label(context, 'Recent'),
          InnerCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++)
                  InkWell(
                    onTap: () => setState(() {
                      _to = recent[i];
                      _step = 1;
                    }),
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
                          _avatar(recent[i], 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(recent[i].name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: pal.ink,
                                    )),
                                Text(recent[i].handle,
                                    style: TextStyle(
                                        fontSize: 11, color: pal.mute)),
                              ],
                            ),
                          ),
                          Icon(Ph.caretRight, size: 13, color: pal.mute),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Transfers between XFLWS users are instant and cannot be reversed. '
          'Always check the name on the next screen before sending.',
          style: TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
        ),
      ],
    );
  }

  // ── step 1 ──────────────────────────────────────────────────────────────

  Widget _stepConfirm(BuildContext context) {
    final pal = context.pal;

    if (_to == null && _method == 'qr') {
      return Column(
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: pal.p1,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.p2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: pal.line, width: 2),
                  ),
                  child: Icon(Ph.qrCode, size: 64, color: pal.mute),
                ),
                const SizedBox(height: 16),
                Text("Point the camera at the recipient's QR code",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: pal.ink)),
                const SizedBox(height: 4),
                Text(
                  'The code carries a verified account ID, so it cannot be '
                  'mistyped.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: pal.mute),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    if (_results.isNotEmpty) setState(() => _to = _results.first);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: pal.act,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Simulate a scan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_to == null) {
      final label = {
        'handle': 'XFLWS handle',
        'phone': 'Phone number',
        'email': 'Email address',
      }[_method]!;
      final hint = {
        'handle': '@mona.k',
        'phone': '+20 10 2244 8891',
        'email': 'name@example.com',
      }[_method]!;
      final found = _find();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(label, style: TextStyle(fontSize: 12, color: pal.mute)),
          const SizedBox(height: 6),
          TextField(
            controller: _query,
            onChanged: (v) {
              setState(() {});
              if (v.length >= 2) _search(v);
            },
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
          ),
          if (found != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _to = found),
              child: InnerCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _avatar(found, 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(found.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: pal.ink,
                                )),
                            Text(found.handle,
                                style: TextStyle(
                                    fontSize: 11, color: pal.mute)),
                          ],
                        ),
                      ),
                      Icon(Ph.caretRight, size: 13, color: pal.mute),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Try @mona.k, @yassin or @sara.h in this prototype.',
              style:
                  TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute)),
        ],
      );
    }

    final p = _to!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, 'Is this the right person?'),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _avatar(p, 64, fontSize: 24),
                const SizedBox(height: 12),
                Text(p.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: pal.ink,
                    )),
                const SizedBox(height: 2),
                Text(p.handle,
                    style: TextStyle(fontSize: 12, color: pal.mute)),
                const SizedBox(height: 8),
                Text(
                  'With XFLWS since ${p.since} \u00B7 found by '
                  '${_method == 'qr' ? 'QR code' : _method}',
                  style: TextStyle(fontSize: 11.5, color: pal.mute),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Transfers are instant and irreversible. If this is not the person '
          'you meant, go back now.',
          style: TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
        ),
      ],
    );
  }

  // ── step 2 ──────────────────────────────────────────────────────────────

  Widget _stepAmount(BuildContext context) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.p2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pal.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount to send',
                  style: TextStyle(fontSize: 11, color: pal.mute)),
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
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
                'Available ${widget.money.format(widget.available, decimals: 2)} '
                '${widget.money.code} \u00B7 limit 50,000 a day',
                style: TextStyle(fontSize: 11, color: pal.mute),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                      () => _amount.text = '${[250, 500, 1000, 5000][i]}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.p1,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${[250, 500, 1000, 5000][i]}',
                        style: TextStyle(fontSize: 12, color: pal.ink)),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text('Note to ${_to!.name.split(' ').first} (optional)',
            style: TextStyle(fontSize: 12, color: pal.mute)),
        const SizedBox(height: 6),
        TextField(
          controller: _note,
          style: TextStyle(fontSize: 14, color: pal.ink),
          decoration: InputDecoration(
            hintText: 'What is this for?',
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
        ),
      ],
    );
  }

  // ── step 3 ──────────────────────────────────────────────────────────────

  Widget _stepReview(BuildContext context) {
    final pal = context.pal;
    final p = _to!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(context, 'Review'),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _avatar(p, 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: pal.ink,
                              )),
                          Text(p.handle,
                              style:
                                  TextStyle(fontSize: 11, color: pal.mute)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _line(context, 'Amount',
                  '${widget.money.format(_amt, decimals: 2)} ${widget.money.code}'),
              _line(context, 'Fee', 'Free'),
              _line(context, 'Arrives', 'Instantly'),
              if (_note.text.trim().isNotEmpty)
                _line(context, 'Note', _note.text.trim()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
            children: [
              const TextSpan(text: 'You are sending '),
              TextSpan(
                text:
                    '${widget.money.format(_amt, decimals: 2)} ${widget.money.code}',
                style: TextStyle(fontWeight: FontWeight.w700, color: pal.ink),
              ),
              const TextSpan(text: ' to '),
              TextSpan(
                text: p.name,
                style: TextStyle(fontWeight: FontWeight.w700, color: pal.ink),
              ),
              const TextSpan(text: '. This cannot be undone.'),
            ],
          ),
        ),
      ],
    );
  }

  // ── shared ──────────────────────────────────────────────────────────────

  Widget _label(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
        child: Text(s,
            style: TextStyle(fontSize: 12, color: context.pal.mute)),
      );

  Widget _avatar(Recipient p, double size, {double? fontSize}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: tickerColour(p.handle), shape: BoxShape.circle),
        child: Text(
          p.name.substring(0, 1),
          style: TextStyle(
            fontSize: fontSize ?? size * 0.36,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      );

  Widget _line(BuildContext context, String k, String v) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: pal.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontSize: 13, color: pal.mute)),
          Text(v,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: pal.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final pal = context.pal;
    final (label, enabled) = switch (_step) {
      1 => ('Yes, continue', _to != null),
      2 => ('Review transfer', !_over),
      3 => (
          'Send ${widget.money.format(_amt, decimals: 2)} ${widget.money.code}',
          true
        ),
      _ => ('Continue', true),
    };

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
            onTap: enabled ? _advance : null,
            child: Opacity(
              opacity: enabled ? 1 : .45,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pal.act,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label,
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

  bool _sending = false;

  Future<void> _advance() async {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.api.transfer(
        amount: _amt,
        to: _to!.handle,
        note: _note.text.trim(),
      );
      widget.onDone?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${widget.money.format(_amt, decimals: 2)} ${widget.money.code} '
          'sent to ${_to!.name}.',
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not reach the server.')));
      }
    }
  }
}
