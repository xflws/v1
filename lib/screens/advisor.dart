// The advisor's view of the app.
//
// Advisors sign in with the same credentials they use in the console, but the
// app gives them only what is useful on a phone: their assigned clients, and
// a call button.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/ph.dart';
import '../data/api.dart';
import '../widgets/atoms.dart';
import 'call.dart';

class AdvisorHome extends StatefulWidget {
  const AdvisorHome({super.key, required this.api, required this.name});

  final Api api;
  final String name;

  @override
  State<AdvisorHome> createState() => _AdvisorHomeState();
}

class _AdvisorHomeState extends State<AdvisorHome> {
  List<Map<String, dynamic>> _clients = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.get('clients');
      final rows = r is List ? r : (r is Map ? (r['clients'] as List? ?? []) : []);
      if (mounted) {
        setState(() {
          _clients = rows
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _call(Map<String, dynamic> c) async {
    try {
      final r = Map<String, dynamic>.from(
          await widget.api.post('call.start', {'with': c['id']}) as Map);
      final call = Map<String, dynamic>.from(r['call'] as Map);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          api: widget.api,
          callId: '${call['id']}',
          otherName: '${call['customerName']}',
          isCaller: true,
        ),
      ));
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
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: pal.ink,
                      )),
                  const SizedBox(height: 4),
                  Text('Your clients',
                      style: TextStyle(fontSize: 11.5, color: pal.mute)),
                ],
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_clients.isEmpty)
            const EmptyState(
              icon: Ph.users,
              title: 'No clients assigned',
              body: 'Clients assigned to you in the console appear here.',
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: InnerCard(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _clients.length; i++)
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
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: pal.ink, shape: BoxShape.circle),
                              child: Text(
                                '${_clients[i]['name'] ?? '?'}'.substring(0, 1),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_clients[i]['name'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: pal.ink,
                                      )),
                                  Text('${_clients[i]['handle'] ?? ''}',
                                      style: TextStyle(
                                          fontSize: 11, color: pal.mute)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _call(_clients[i]),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: pal.act, shape: BoxShape.circle),
                                child: const Icon(Ph.videoCamera,
                                    size: 18, color: Colors.white),
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
