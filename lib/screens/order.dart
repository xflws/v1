// The order ticket — `[data-scr="order"]` and paintOrder().
//
// One deliberate difference from the PWA: the prototype computes the fee
// itself as gross * 0.15%. This asks `?r=orders.quote` instead, so the ticket
// shows exactly what the fill will charge. A ticket that computes its own fee
// and a statement that uses the engine's will eventually disagree, and the
// customer is the one who finds out.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../widgets/atoms.dart';
import '../widgets/holdings.dart' show tickerColour;

class OrderScreen extends StatefulWidget {
  const OrderScreen({
    super.key,
    required this.api,
    required this.instrument,
    required this.money,
    required this.side,
    this.holding,
    this.available = 0,
    this.logoUrl,
    this.onPlaced,
  });

  final Api api;
  final Instrument instrument;
  final Money money;

  /// 'buy' or 'sell'.
  final String side;
  final Holding? holding;

  /// Spendable cash — `available`, never the ledger balance.
  final num available;
  final String Function(String ticker)? logoUrl;
  final VoidCallback? onPlaced;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late String _side = widget.side;
  String _kind = 'Market';
  bool _byValue = false;
  final TextEditingController _qty = TextEditingController(text: '10');
  final TextEditingController _limit = TextEditingController();

  Map<String, dynamic>? _quote;
  bool _quoting = false;
  bool _placing = false;
  String? _error;

  bool get _isFund =>
      widget.instrument.ticker.startsWith('AZ') ||
      widget.instrument.ticker.startsWith('XF') ||
      widget.instrument.ticker == 'GLD';

  num get _price => _kind == 'Limit'
      ? (num.tryParse(_limit.text) ?? widget.instrument.last)
      : widget.instrument.last;

  /// ordShares() — when entering a value, divide by price to get units.
  num get _shares {
    final v = num.tryParse(_qty.text) ?? 0;
    if (_byValue || _isFund) return _price == 0 ? 0 : v / _price;
    return v;
  }

  num get _owned => widget.holding?.units ?? 0;

  @override
  void initState() {
    super.initState();
    _limit.text = widget.instrument.last.toStringAsFixed(2);
    _refreshQuote();
  }

  @override
  void dispose() {
    _qty.dispose();
    _limit.dispose();
    super.dispose();
  }

  /// The fee breakdown comes from the server, so the ticket and the statement
  /// cannot drift apart.
  Future<void> _refreshQuote() async {
    if (_shares <= 0) {
      setState(() => _quote = null);
      return;
    }
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final q = await widget.api.quote(
        ticker: widget.instrument.ticker,
        side: _side.toLowerCase(),
        quantity: _shares,
        limit: _kind == 'Limit' ? _price : null,
      );
      if (mounted) setState(() => _quote = q);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not price this order.');
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  num _q(String key) {
    final v = _quote?[key];
    return v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  }

  /// Buying more than the available cash, or selling more than is owned.
  bool get _short => _side == 'Buy'
      ? _q('total') > widget.available && _quote != null
      : _shares > _owned;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _header(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sideToggle(context),
                      _amountCard(context),
                      _quickAmounts(context),
                      _sectionLabel(context, 'Order type'),
                      _kindToggle(context),
                      if (_kind == 'Limit' && !_isFund) _limitField(context),
                      const SizedBox(height: 16),
                      _summary(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _footer(context),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(s,
            style: TextStyle(fontSize: 12, color: context.pal.mute)),
      );

  Widget _header(BuildContext context) {
    final pal = context.pal;
    final s = widget.instrument;
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
            Mark(
              monogram: s.ticker.substring(0, s.ticker.length.clamp(0, 2)),
              colour: tickerColour(s.ticker),
              ticker: s.ticker,
              size: 38,
              logoUrl: widget.logoUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s.ticker} \u00B7 ${s.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                  Text(
                    _isFund
                        ? 'NAV ${widget.money.code} '
                            '${widget.money.format(s.last, decimals: 4)}'
                        : '${widget.money.code} '
                            '${widget.money.format(s.last, decimals: 2)} \u00B7 '
                            '${s.up ? '\u25B2' : '\u25BC'} '
                            '${s.change.abs().toStringAsFixed(2)}%',
                    style: TextStyle(fontSize: 11.5, color: pal.mute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Buy fills green, Sell fills red — the source colours the active side.
  Widget _sideToggle(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.p1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final x in ['Buy', 'Sell'])
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _side = x);
                  _refreshQuote();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: x == _side
                        ? (x == 'Buy' ? pal.gain : pal.loss)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    x,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          x == _side ? FontWeight.w600 : FontWeight.w400,
                      color: x == _side ? Colors.white : pal.mute,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _amountCard(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.p2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount', style: TextStyle(fontSize: 11, color: pal.mute)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _refreshQuote(),
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
              Text(
                _isFund
                    ? widget.money.code
                    : (_byValue ? widget.money.code : 'shares'),
                style: TextStyle(fontSize: 13, color: pal.mute),
              ),
            ],
          ),
          if (!_isFund) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (k, l) in [
                  (false, 'In shares'),
                  (true, 'In ${widget.money.code}')
                ]) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() => _byValue = k);
                      _refreshQuote();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: k == _byValue ? pal.tint : pal.p1,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: k == _byValue
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: k == _byValue ? pal.actDk : pal.mute,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickAmounts(BuildContext context) {
    final pal = context.pal;
    final amounts = (_isFund || _byValue)
        ? [1000, 5000, 10000, 25000]
        : [10, 50, 100, 500];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          for (var i = 0; i < amounts.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _qty.text = '${amounts[i]}';
                  _refreshQuote();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.p1,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${amounts[i]}',
                      style: TextStyle(fontSize: 12, color: pal.ink)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kindToggle(BuildContext context) {
    final pal = context.pal;
    final kinds = _isFund ? ['Forward NAV'] : ['Market', 'Limit'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.p1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final k in kinds)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _kind = k);
                  _refreshQuote();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: k == _kind || kinds.length == 1
                        ? pal.p2
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    k,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          k == _kind ? FontWeight.w600 : FontWeight.w400,
                      color: k == _kind ? pal.ink : pal.mute,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _limitField(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Limit price',
              style: TextStyle(fontSize: 12, color: pal.mute)),
          const SizedBox(height: 6),
          TextField(
            controller: _limit,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _refreshQuote(),
            style: TextStyle(
              fontSize: 14,
              color: pal.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: pal.p2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      ),
    );
  }

  /// The summary is the server's own breakdown. Nothing here is computed
  /// locally except the unit count the customer typed.
  Widget _summary(BuildContext context) {
    final pal = context.pal;

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal.loss.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Ph.warningCircle, size: 15, color: pal.loss),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!,
                  style: TextStyle(fontSize: 12.5, color: pal.loss)),
            ),
          ],
        ),
      );
    }

    if (_quote == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pal.p1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            _quoting ? 'Pricing…' : 'Enter an amount to see the cost.',
            style: TextStyle(fontSize: 12.5, color: pal.mute),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              _line(context, _isFund ? 'Estimated units' : 'Shares',
                  _shares.toStringAsFixed(_isFund ? 4 : 2), true),
              _line(
                context,
                _isFund
                    ? 'Last published NAV'
                    : (_kind == 'Limit' ? 'Limit price' : 'Estimated price'),
                widget.money.format(_price, decimals: _isFund ? 4 : 2),
                false,
              ),
              _line(context, 'Gross',
                  widget.money.format(_q('gross'), decimals: 2), false),
              if (_q('commission') != 0)
                _line(context, 'Commission',
                    widget.money.format(_q('commission'), decimals: 2), false),
              if (_q('exchangeFees') != 0)
                _line(context, 'Exchange fees',
                    widget.money.format(_q('exchangeFees'), decimals: 2), false),
              if (_q('tax') != 0)
                _line(context, 'Tax',
                    widget.money.format(_q('tax'), decimals: 2), false),
              _line(
                context,
                _side == 'Buy' ? 'Total to pay' : 'Net proceeds',
                widget.money.format(_q('total'), decimals: 2),
                false,
                bold: true,
              ),
            ],
          ),
        ),
        if (_short) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Ph.warningCircle, size: 14, color: pal.loss),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _side == 'Buy'
                      ? 'That is more than your available cash of '
                          '${widget.money.format(widget.available, decimals: 2)}.'
                      : 'You hold ${_owned.toStringAsFixed(2)} '
                          '${widget.holding?.unitLabel ?? 'units'}.',
                  style: TextStyle(fontSize: 12, color: pal.loss),
                ),
              ),
            ],
          ),
        ],
        if (_isFund) ...[
          const SizedBox(height: 10),
          Text(
            'Units are priced once a day at NAV. Orders placed after the '
            'cut-off execute on the next dealing day, so the price you pay is '
            'not known when you order.',
            style: TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
          ),
        ],
      ],
    );
  }

  Widget _line(BuildContext context, String k, String v, bool first,
      {bool bold = false}) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: pal.line),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: TextStyle(
                fontSize: 13,
                color: bold ? pal.ink : pal.mute,
                fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
              )),
          Text(v,
              style: TextStyle(
                fontSize: bold ? 14 : 13,
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
    final ready = _quote != null && !_short && !_placing;
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
            onTap: ready ? _review : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ready ? pal.act : pal.mute.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(999),
              ),
              child: _placing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Review order',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      )),
            ),
          ),
        ),
      ),
    );
  }

  /// The confirmation step. The customer sees the server's numbers once more
  /// before anything is placed.
  void _review() {
    final pal = context.pal;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.p2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pal.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Confirm your order',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: pal.ink,
                  )),
              const SizedBox(height: 4),
              Text(
                '$_side ${_shares.toStringAsFixed(_isFund ? 4 : 2)} '
                '${widget.instrument.ticker} at '
                '${_kind == 'Limit' ? 'a limit of ' : ''}'
                '${widget.money.format(_price, decimals: 2)}',
                style: TextStyle(fontSize: 12.5, color: pal.mute),
              ),
              const SizedBox(height: 16),
              InnerCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _line(context, 'Gross',
                        widget.money.format(_q('gross'), decimals: 2), true),
                    if (_q('commission') != 0)
                      _line(context, 'Commission',
                          widget.money.format(_q('commission'), decimals: 2),
                          false),
                    _line(
                      context,
                      _side == 'Buy' ? 'Total to pay' : 'Net proceeds',
                      widget.money.format(_q('total'), decimals: 2),
                      false,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.of(sheet).pop();
                  _place();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.act,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Place $_side order',
                      style: const TextStyle(
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

  Future<void> _place() async {
    setState(() => _placing = true);
    try {
      await widget.api.placeOrder(
        ticker: widget.instrument.ticker,
        side: _side.toLowerCase(),
        quantity: _shares,
        limit: _kind == 'Limit' ? _price : null,
      );
      if (!mounted) return;
      widget.onPlaced?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_side order placed.')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not place the order.');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}
