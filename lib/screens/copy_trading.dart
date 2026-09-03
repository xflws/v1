// Copy trading — `?r=copy`, `copy.start`, `copy.settings`.
//
// The backend already holds the leaderboard, the relationships, the allocation
// and the per-relationship limits, so this screen is a view over them.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/api.dart';
import '../widgets/atoms.dart';
import 'more_screens.dart' show PushedHeader;

class CopyTradingScreen extends StatefulWidget {
  const CopyTradingScreen({super.key, required this.api, required this.money});

  final Api api;
  final Money money;

  @override
  State<CopyTradingScreen> createState() => _CopyTradingScreenState();
}

class _CopyTradingScreenState extends State<CopyTradingScreen> {
  List<Map<String, dynamic>> _leaders = const [];
  List<Map<String, dynamic>> _mine = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = Map<String, dynamic>.from(await widget.api.get('copy') as Map);
      if (!mounted) return;
      setState(() {
        _leaders = (r['leaderboard'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _mine = (r['relationships'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load.'; _loading = false; });
    }
  }

  Future<void> _follow(Map<String, dynamic> leader) async {
    final amount = await _askAllocation(leader);
    if (amount == null) return;
    try {
      await widget.api.post('copy.start', {
        'leaderId': leader['id'] ?? leader['userId'],
        'options': {'allocation': amount},
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Now copying ${leader['name'] ?? ''}.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Allocation is asked for up front rather than defaulted: how much of your
  /// money follows someone else's decisions is the whole risk of the feature.
  Future<num?> _askAllocation(Map<String, dynamic> leader) {
    final pal = context.pal;
    final c = TextEditingController(text: '5000');
    return showModalBottomSheet<num>(
      context: context,
      backgroundColor: pal.p2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Copy ${leader['name'] ?? ''}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: pal.ink,
                    )),
                const SizedBox(height: 4),
                Text(
                  'How much should follow their trades? Only this amount is '
                  'at risk — the rest of your portfolio is untouched.',
                  style: TextStyle(
                      fontSize: 12, height: 1.45, color: pal.mute),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: c,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: pal.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    prefixText: '${widget.money.code}  ',
                    filled: true,
                    fillColor: pal.p1,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.of(sheet)
                      .pop(num.tryParse(c.text) ?? 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pal.act,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Start copying',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        )),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Past returns do not predict future ones. A trader who did '
                  'well last year can lose money this one, and you carry that '
                  'loss.',
                  style: TextStyle(
                      fontSize: 11, height: 1.4, color: pal.mute),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _stop(Map<String, dynamic> rel) async {
    try {
      await widget.api.post('copy.transition', {
        'id': rel['id'],
        'to': 'stopped',
      });
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
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
              title: 'Copy trading',
              subtitle: 'Follow another investor automatically'),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    // Copy trading sits behind a feature flag, so a refusal
                    // here is usually "not enabled", not a fault.
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: pal.p1,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_error!,
                          style: TextStyle(
                              fontSize: 12.5, height: 1.45, color: pal.mute)),
                    ),
                  if (_mine.isNotEmpty) ...[
                    _cap(context, 'You are copying'),
                    InnerCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < _mine.length; i++)
                            _relRow(context, _mine[i], i == 0),
                        ],
                      ),
                    ),
                  ],
                  if (_error == null) ...[
                    _cap(context, 'Top investors'),
                    if (_leaders.isEmpty)
                      const EmptyState(
                        icon: Ph.usersThree,
                        title: 'Nobody to copy yet',
                        body: 'Investors who opt in to being copied appear here.',
                      )
                    else
                      InnerCard(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < _leaders.length; i++)
                              _leaderRow(context, _leaders[i], i == 0),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Copying places real orders with your money. Fees and '
                    'slippage apply to every copied trade, and a trade you '
                    'would not have made yourself is still yours.',
                    style: TextStyle(
                        fontSize: 11.5, height: 1.45, color: pal.mute),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cap(BuildContext context, String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(s,
            style: TextStyle(fontSize: 12, color: context.pal.mute)),
      );

  Widget _leaderRow(BuildContext context, Map<String, dynamic> l, bool first) {
    final pal = context.pal;
    final ret = (l['return'] ?? l['returnPct'] ?? 0);
    final pct = ret is num ? ret : num.tryParse('$ret') ?? 0;
    return Container(
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
            decoration: BoxDecoration(color: pal.ink, shape: BoxShape.circle),
            child: Text('${l['name'] ?? '?'}'.substring(0, 1),
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
                Text('${l['name'] ?? ''}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: pal.ink,
                    )),
                Text('${l['followers'] ?? 0} following',
                    style: TextStyle(fontSize: 11, color: pal.mute)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PctTag(delta: pct, up: pct >= 0, fontSize: 13),
              Text('this year',
                  style: TextStyle(fontSize: 10, color: pal.mute)),
            ],
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _follow(l),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: pal.tint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Copy',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pal.actDk,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _relRow(BuildContext context, Map<String, dynamic> rel, bool first) {
    final pal = context.pal;
    final state = '${rel['state'] ?? 'active'}';
    return Container(
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
            child: Icon(Ph.copy, size: 18, color: pal.actDk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rel['leaderName'] ?? rel['leaderId'] ?? ''}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: pal.ink,
                    )),
                Text(
                  '${widget.money.format((rel['allocation'] ?? 0) as num)} '
                  '${widget.money.code} allocated',
                  style: TextStyle(fontSize: 11, color: pal.mute),
                ),
              ],
            ),
          ),
          Pill(
            text: state,
            tone: state == 'active' ? Tone.gain(context) : Tone.mute(context),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _stop(rel),
            child: Text('Stop',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: pal.loss,
                )),
          ),
        ],
      ),
    );
  }
}
