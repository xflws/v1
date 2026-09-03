// The voice sheet — ports dlgVoice(), startVoice(), voiceResult() and
// paintWave(), and adds the spoken reply the PWA never had.
//
// Speech in is `speech_to_text`; speech out is `flutter_tts`. Both degrade to
// text if the platform refuses, which matters on web where a browser may have
// neither.
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../core/tokens.dart';
import '../core/ph.dart';
import '../core/voice_command.dart';
import '../widgets/atoms.dart';

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({
    super.key,
    required this.universe,
    required this.currency,
    required this.onRun,
    this.speakReplies = true,
  });

  /// (ticker, name) pairs the parser matches spoken words against.
  final List<(String, String)> universe;
  final String currency;

  /// Executes a recognised intent. Returns what should be said back.
  final String Function(VoiceIntent intent) onRun;

  final bool speakReplies;

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _typed = TextEditingController();

  bool _available = false;
  bool _ttsReady = false;
  bool _listening = false;
  String _state = 'Tap to speak';
  String _heard = '';
  VoiceIntent? _intent;
  String? _reply;

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _wave.dispose();
    _typed.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _available = await _speech.initialize(
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') {
            setState(() {
              _listening = false;
              if (_heard.isEmpty) _state = 'Tap to speak';
            });
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _state = 'Could not hear that';
          });
        },
      );
    } catch (_) {
      _available = false;
    }
    if (mounted) {
      setState(() {
        if (!_available) _state = 'Voice input is not available here';
      });
    }
    // Initialize TTS with a completion handler so we know when it's ready.
    try {
      _tts.setCompletionHandler(() {
        debugPrint('flutter_tts completed speaking');
      });
      _tts.setErrorHandler((msg) {
        debugPrint('flutter_tts error: $msg');
      });
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      // Speak a silent empty string to force the engine to initialize.
      // On Android, the first speak() call can fail if the engine hasn't
      // warmed up yet.
      await _tts.speak('');
      if (mounted) setState(() => _ttsReady = true);
    } catch (e) {
      debugPrint('flutter_tts init failed: $e');
    }
  }

  Future<void> _toggleListen() async {
    if (!_available) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _state = 'Listening…';
      _heard = '';
      _intent = null;
      _reply = null;
    });
    await _speech.listen(
      localeId: 'en_US',
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          _heard = r.recognizedWords;
          _state = r.finalResult ? 'Heard' : 'Listening…';
        });
        if (r.finalResult) _resolve(r.recognizedWords);
      },
    );
  }

  void _resolve(String text) {
    final it = parseCommand(text, widget.universe,
        currency: widget.currency);
    setState(() {
      _intent = it;
      _typed.text = it?.cmd ?? text;
    });
    if (it == null) _say("I did not catch a command in that.");
  }

  Future<void> _say(String text) async {
    setState(() => _reply = text);
    if (!widget.speakReplies || !_ttsReady) return;
    try {
      await _tts.stop();
      final result = await _tts.speak(text);
      if (result != 1) {
        debugPrint('flutter_tts.speak returned $result (failure)');
      }
    } catch (e) {
      debugPrint('flutter_tts.speak failed: $e');
    }
  }

  void _run() {
    final it = _intent;
    if (it == null) return;
    final spoken = widget.onRun(it);
    _say(spoken);
    // Keep the sheet open briefly so the user sees and hears the reply.
    // Navigation and screen-opening intents still close it, but after a
    // short delay so the confirmation is visible.
    if (it.kind != IntentKind.ask) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
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
              Center(
                child: GestureDetector(
                  onTap: _toggleListen,
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _available ? pal.act : pal.mute,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: pal.act.withValues(alpha: .35),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _listening
                          ? Ph.microphoneFill
                          : Ph.microphoneSlashFill,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _waveform(context),
              const SizedBox(height: 8),
              Text(_state,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: pal.ink,
                  )),
              const SizedBox(height: 12),
              SizedBox(
                height: 24,
                child: Text(_heard,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: pal.ink)),
              ),
              if (_intent != null) _intentCard(context, _intent!),
              if (_intent == null && _heard.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: pal.p1,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'I could not turn that into a command. Try one of the '
                    'examples below.',
                    style: TextStyle(fontSize: 12.5, color: pal.mute),
                  ),
                ),
              if (_reply != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Ph.speakerHigh, size: 15, color: pal.actDk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_reply!,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: pal.actDk)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: pal.act,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Done',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            )),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text('Or type a command',
                  style: TextStyle(fontSize: 12, color: pal.mute)),
              const SizedBox(height: 6),
              TextField(
                controller: _typed,
                onSubmitted: (v) {
                  setState(() => _heard = v);
                  _resolve(v);
                },
                style: TextStyle(fontSize: 14, color: pal.ink),
                decoration: InputDecoration(
                  hintText: 'Buy 50 Cleopatra',
                  hintStyle: TextStyle(fontSize: 14, color: pal.mute),
                  filled: true,
                  fillColor: pal.p1,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Try', style: TextStyle(fontSize: 12, color: pal.mute)),
              const SizedBox(height: 8),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final x in kVoiceExamples) ...[
                      GestureDetector(
                        onTap: () {
                          _typed.text = x;
                          setState(() => _heard = x);
                          _resolve(x);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: pal.p1,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(x,
                              style: TextStyle(
                                  fontSize: 12, color: pal.ink)),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nine bars that rise while listening, from paintWave().
  Widget _waveform(BuildContext context) {
    final pal = context.pal;
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 9; i++) ...[
              Container(
                width: 4,
                height: _listening
                    ? 6 +
                        ((i * 37) % 16) *
                            (0.5 + 0.5 * ((i.isEven) ? _wave.value : 1 - _wave.value))
                    : 4,
                decoration: BoxDecoration(
                  color: pal.act.withValues(alpha: _listening ? .9 : .25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _intentCard(BuildContext context, VoiceIntent it) {
    final pal = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (it.normalised.isNotEmpty &&
            it.normalised != _heard.toLowerCase().trim())
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              'Heard \u201C$_heard\u201D \u2192 read as ${it.cmd}',
              style: TextStyle(fontSize: 11, color: pal.mute),
            ),
          ),
        const SizedBox(height: 12),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                  child: Icon(it.icon, size: 19, color: pal.actDk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.say,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: pal.ink,
                          )),
                      Text(it.authLabel,
                          style:
                              TextStyle(fontSize: 11, color: pal.mute)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _run,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pal.act,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('Do it',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                )),
          ),
        ),
        // A voice command never completes a money movement on its own: it
        // opens the ticket pre-filled, and the customer confirms there.
        if (it.auth > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'This opens the screen with the details filled in. Nothing moves '
              'until you confirm it there.',
              style:
                  TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
            ),
          ),
      ],
    );
  }
}
