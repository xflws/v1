// The advisor call, in simulated-media mode.
//
// flutter_webrtc is not in this build: 0.12.12 declares compileSdk 31 and
// cannot be built against AGP 9. Rather than block the whole app on one
// plugin, the media stream is stubbed and everything else stays real.
//
// Live, through the API: the whiteboard synchronised stroke by stroke, chat,
// presence, and the call lifecycle. Simulated: only the audio and video
// streams — and the screen says so, because a blank video panel would leave
// the customer assuming the app is broken.
//
// Restoring real media is two changes: uncomment flutter_webrtc in
// pubspec.yaml and restore this file from the archive. Nothing on the server
// changes; the signalling routes are plain HTTP and were never tied to the
// plugin.
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/ph.dart';
import '../data/api.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.api,
    required this.callId,
    required this.otherName,
    required this.isCaller,
  });

  final Api api;
  final String callId;
  final String otherName;

  /// Whoever started the call makes the offer; the other side answers.
  final bool isCaller;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _poll;
  Timer? _clock;
  int _seconds = 0;

  bool _micOn = true;
  bool _camOn = true;
  bool _otherPresent = false;

  /// board | chat | null
  String? _panel;

  int _sinceStroke = 0;
  final List<_Stroke> _strokes = [];
  _Stroke? _drawing;
  Color _penColour = const Color(0xFF062E54);

  final List<(bool mine, String text)> _chat = [];
  final TextEditingController _chatInput = TextEditingController();


  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    _chatInput.dispose();
    super.dispose();
  }

  String get _elapsed {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// The same poll the real screen uses. Signals are drained and discarded —
  /// there is no peer connection to feed them to — but strokes, presence and
  /// call state are handled exactly as they would be.
  Future<void> _tick() async {
    try {
      final r = Map<String, dynamic>.from(await widget.api
          .get('call.poll', {'id': widget.callId, 'sinceStroke': '$_sinceStroke'})
          as Map);

      if (r['state'] == 'ended') {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      if (mounted) setState(() => _otherPresent = r['otherPresent'] == true);

      final strokes = (r['strokes'] as List? ?? const []);
      if (strokes.isNotEmpty && mounted) {
        setState(() {
          for (final raw in strokes) {
            final st = Map<String, dynamic>.from(raw as Map);
            final n = (st['n'] as num).toInt();
            if (n > _sinceStroke) _sinceStroke = n;
            _strokes.add(_Stroke.fromJson(st));
          }
        });
      }
    } catch (_) {
      // A dropped poll is not fatal; the next one catches up.
    }
  }

  Future<void> _hangUp() async {
    try {
      await widget.api.post('call.end', {'id': widget.callId});
    } catch (_) {}
    if (mounted) Navigator.of(context).maybePop();
  }

  void _toggleMic() => setState(() => _micOn = !_micOn);

  void _toggleCam() => setState(() => _camOn = !_camOn);

  // ── whiteboard ─────────────────────────────────────────────────────────

  void _penDown(Offset p, Size size) {
    setState(() => _drawing = _Stroke(
          colour: _penColour,
          width: 3,
          points: [_norm(p, size)],
        ));
  }

  void _penMove(Offset p, Size size) {
    final d = _drawing;
    if (d == null) return;
    setState(() => d.points.add(_norm(p, size)));
  }

  Future<void> _penUp() async {
    final d = _drawing;
    if (d == null || d.points.length < 2) {
      setState(() => _drawing = null);
      return;
    }
    setState(() {
      _strokes.add(d);
      _drawing = null;
    });
    try {
      await widget.api.post('call.draw', {
        'id': widget.callId,
        'strokes': [d.toJson()],
      });
    } catch (_) {}
  }

  /// Points are stored 0..1 so the two devices agree regardless of screen size.
  Offset _norm(Offset p, Size s) =>
      Offset(p.dx / (s.width == 0 ? 1 : s.width),
          p.dy / (s.height == 0 ? 1 : s.height));

  Future<void> _clearBoard() async {
    setState(() {
      _strokes.clear();
      _sinceStroke = 0;
    });
    try {
      await widget.api.post('call.clear', {'id': widget.callId});
    } catch (_) {}
  }

  // ── chat ───────────────────────────────────────────────────────────────

  Future<void> _sendChat() async {
    final t = _chatInput.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _chat.add((true, t));
      _chatInput.clear();
    });
    try {
      await widget.api.post('chats.send', {'body': t});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: const Color(0xFF0C1211),
      body: Stack(
        children: [
          Positioned.fill(
            child: _panel == 'board'
                ? _board(context)
                : _stage(context),
          ),

          // Own camera, small, top right.
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 12,
            child: Container(
              width: 96,
              height: 132,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Center(
                child: Icon(_camOn ? Ph.videoCamera : Ph.videoCameraSlash,
                    size: 22, color: Colors.white38),
              ),
            ),
          ),

          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _otherPresent ? pal.gain : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _otherPresent
                          ? 'Connected \u00B7 $_elapsed'
                          : 'Waiting for ${widget.otherName}…',
                      style: const TextStyle(
                          fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_panel == 'chat')
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: _chatPanel(context),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _controls(context),
          ),
        ],
      ),
    );
  }

  /// Stands in for the remote video: the other party's initial over a calm
  /// gradient, with a line saying the stream is simulated. A blank panel would
  /// read as a crash.
  Widget _stage(BuildContext context) {
    final initial = widget.otherName.isEmpty
        ? '?'
        : widget.otherName.substring(0, 1).toUpperCase();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF06283D), Color(0xFF0C1211)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 108,
              height: 108,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Text(initial,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  )),
            ),
            const SizedBox(height: 18),
            Text(widget.otherName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                )),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Video is simulated in this build. The whiteboard and chat are '
                'live and shared with ${widget.otherName}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: .72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(BuildContext context) => Container(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            return GestureDetector(
              onPanStart: (d) => _penDown(d.localPosition, size),
              onPanUpdate: (d) => _penMove(d.localPosition, size),
              onPanEnd: (_) => _penUp(),
              child: CustomPaint(
                size: size,
                painter: _BoardPainter(
                  strokes: [..._strokes, if (_drawing != null) _drawing!],
                ),
              ),
            );
          },
        ),
      );

  Widget _chatPanel(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                reverse: true,
                children: [
                  for (final m in _chat.reversed)
                    Align(
                      alignment:
                          m.$1 ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 240),
                        decoration: BoxDecoration(
                          color: m.$1
                              ? context.pal.act
                              : Colors.white.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(m.$2,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInput,
                    onSubmitted: (_) => _sendChat(),
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: Colors.white54),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendChat,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: context.pal.act, shape: BoxShape.circle),
                    child: const Icon(Ph.play, size: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _controls(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: .7)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_panel == 'board') _penBar(context),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Choose between two constants rather than constructing
                  // one, so the icon tree-shaker can still see both.
                  _btn(_micOn ? Ph.microphoneFill : Ph.microphoneSlashFill,
                      _toggleMic,
                      on: _micOn),
                  _btn(_camOn ? Ph.videoCamera : Ph.videoCameraSlash,
                      _toggleCam,
                      on: _camOn),
                  // The icon font is subsetted to what the PWA used and has
                  // no pen glyph; `squaresFour` reads as a board well enough.
                  _btn(Ph.squaresFour,
                      () => setState(
                          () => _panel = _panel == 'board' ? null : 'board'),
                      on: _panel == 'board'),
                  _btn(Ph.chatCircle,
                      () => setState(
                          () => _panel = _panel == 'chat' ? null : 'chat'),
                      on: _panel == 'chat'),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _hangUp,
                    child: Container(
                      width: 58,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: pal.loss,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Ph.phoneX,
                          size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _penBar(BuildContext context) {
    const colours = [
      Color(0xFF062E54),
      Color(0xFFFB721C),
      Color(0xFFA8192A),
      Color(0xFF006B61),
      Color(0xFF111111),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final c in colours) ...[
            GestureDetector(
              onTap: () => setState(() => _penColour = c),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _penColour == c ? Colors.white : Colors.white24,
                    width: _penColour == c ? 3 : 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: _clearBoard,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Clear',
                  style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, {bool on = true}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on
                  ? Colors.white.withValues(alpha: .18)
                  : Colors.white.withValues(alpha: .06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 20,
                color: on ? Colors.white : Colors.white38),
          ),
        ),
      );
}

class _Stroke {
  _Stroke({required this.colour, required this.width, required this.points});

  final Color colour;
  final double width;

  /// Normalised 0..1, so both devices agree regardless of screen size.
  final List<Offset> points;

  Map<String, dynamic> toJson() => {
        'kind': 'line',
        'colour':
            '#${(colour.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'width': width,
        'points': [
          for (final p in points) ...[p.dx, p.dy]
        ],
      };

  factory _Stroke.fromJson(Map<String, dynamic> j) {
    final flat = (j['points'] as List? ?? const [])
        .map((e) => e is num ? e.toDouble() : 0.0)
        .toList();
    final pts = <Offset>[];
    for (var i = 0; i + 1 < flat.length; i += 2) {
      pts.add(Offset(flat[i], flat[i + 1]));
    }
    final hex = '${j['colour'] ?? '#062E54'}'.replaceAll('#', '');
    return _Stroke(
      colour: Color(int.tryParse('FF$hex', radix: 16) ?? 0xFF062E54),
      width: (j['width'] as num?)?.toDouble() ?? 3,
      points: pts,
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({required this.strokes});

  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.length < 2) continue;
      final path = Path();
      final first = s.points.first;
      path.moveTo(first.dx * size.width, first.dy * size.height);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = s.colour,
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.strokes.length != strokes.length;
}
