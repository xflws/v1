import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/tokens.dart';
import 'core/money.dart';
import 'core/theme_controller.dart';
import 'core/ph.dart';
import 'data/api.dart';
import 'data/models.dart';
import 'screens/home.dart';
import 'screens/advisor.dart';
import 'screens/call.dart';
import 'dart:async';
import 'screens/portfolio.dart';
import 'screens/markets.dart';
import 'screens/discover_money_settings.dart';
import 'widgets/tab_bar.dart';
import 'widgets/voice_fab.dart';
import 'widgets/voice_sheet.dart';
import 'core/voice_command.dart';
import 'screens/transfer.dart';
import 'screens/more_screens.dart';
import 'widgets/open_security.dart';

/// Point this at your deployment. On the Android emulator, localhost on the
/// host machine is 10.0.2.2.
const String kBaseUrl =
    String.fromEnvironment('XFLWS_API', defaultValue: 'https://api.xflws.com');

void main() => runApp(const XflwsApp());

class XflwsApp extends StatefulWidget {
  const XflwsApp({super.key});

  @override
  State<XflwsApp> createState() => _XflwsAppState();
}

class _XflwsAppState extends State<XflwsApp> {
  final Api _api = Api(baseUrl: kBaseUrl);
  final Money _money = Money();
  final ThemeController _theme = ThemeController();
  bool _booting = true;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _theme.load();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      await _api.restoreSession();
      if (!mounted) return;
      if (!_api.signedIn || !await _api.sessionAlive()) {
        setState(() => _booting = false);
        return;
      }
      final session = Session.fromJson(await _api.me());
      try {
        _money.adopt(await _api.currencies());
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _session = session;
        _booting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _booting = false);
    }
  }

  @override
  void dispose() {
    _api.close();
    _money.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pal = Pal.bridgeLight;
    return AnimatedBuilder(
      animation: _theme,
      builder: (context, _) => Tokens(
        pal: pal,
        hero: _theme.hero,
        child: MaterialApp(
          title: 'XFLWS',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: T.family,
            scaffoldBackgroundColor: pal.p0,
            colorScheme: ColorScheme.fromSeed(
              seedColor: pal.act,
              primary: pal.act,
              surface: pal.p2,
              error: pal.loss,
            ),
            splashFactory: InkRipple.splashFactory,
          ),
          builder: (context, child) => ColoredBox(
            color: const Color(0xFFE8E6E2),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kShellMaxWidth),
                child: Material(color: pal.p0, child: child),
              ),
            ),
          ),
          home: _booting
              ? const _AppLoadingScreen()
              : (_session != null
                  ? Shell(
                      api: _api,
                      money: _money,
                      session: _session!,
                      theme: _theme,
                    )
                  : SignInScreen(api: _api, money: _money, theme: _theme)),
        ),
      ),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: pal.act),
            const SizedBox(height: 16),
            Text('Restoring session…', style: T.body.copyWith(color: pal.mute)),
          ],
        ),
      ),
    );
  }
}

// ── sign in ──────────────────────────────────────────────────────────────

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.api,
    required this.money,
    this.theme,
  });

  final Api api;
  final Money money;
  final ThemeController? theme;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _user = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.login(_user.text.trim(), _pw.text);
      // Save session cookie for persistence across app launches.
      await widget.api.persistSession();
      final session = Session.fromJson(await widget.api.me());

      // Live rates are a nicety, not a precondition for signing in. Catching
      // only ApiException let a shape mismatch (a TypeError) escape and fail
      // the whole login with a misleading connectivity message. Anything that
      // goes wrong here must leave the indicative rates in place and let the
      // user through; the picker already says the rates are not live.
      try {
        widget.money.adopt(await widget.api.currencies());
      } catch (_) {
        // Indicative rates stand.
      }

      if (!mounted) return;
      if (!session.user.isCustomer) {
        // Staff get the advisor view, not the customer tabs.
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => AdvisorHome(
            api: widget.api,
            name: session.user.name,
          ),
        ));
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => Shell(
          api: widget.api,
          money: widget.money,
          session: session,
          theme: widget.theme,
        ),
      ));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not connect to the server. '
          'Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App logo — the XFLWS brand mark, centered.
                SvgPicture.asset(
                  'assets/brand/icon.svg',
                  width: 72,
                  height: 72,
                ),
                const SizedBox(height: 24),
                Text('Welcome back',
                    textAlign: TextAlign.center,
                    style: T.bigNum.copyWith(color: pal.ink, fontSize: 26)),
                const SizedBox(height: 6),
                Text('Sign in to your XFLWS account.',
                    textAlign: TextAlign.center,
                    style: T.body.copyWith(color: pal.mute)),
                const SizedBox(height: 32),
                _field(
                  controller: _user,
                  label: 'Phone, email or handle',
                  hint: 'you@example.com',
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _pw,
                  label: 'Password',
                  hint: 'Your password',
                  obscure: _obscure,
                  onSubmit: _submit,
                  suffix: IconButton(
                    icon: Icon(Ph.eye, size: 18, color: pal.mute),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Ph.warningCircle, size: 15, color: pal.loss),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        // Diagnostics run to several lines and must not clip —
                        // the useful part is usually at the end.
                        child: SelectableText(
                          _error!,
                          style: T.rowSub.copyWith(color: pal.loss, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: pal.act,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign in',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    VoidCallback? onSubmit,
  }) {
    final pal = context.pal;
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(label, style: T.label.copyWith(color: pal.mute)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          onSubmitted: (_) => onSubmit?.call(),
          style: T.body.copyWith(color: pal.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: T.body.copyWith(color: pal.mute),
            filled: true,
            fillColor: pal.p2,
            suffixIcon: suffix,
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
      ),
    );
  }
}

// ── shell ────────────────────────────────────────────────────────────────

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.api,
    required this.money,
    required this.session,
    this.theme,
  });

  final Api api;
  final Money money;
  final Session session;
  final ThemeController? theme;

  @override
  State<Shell> createState() => _ShellState();
}

/// Tab order matching XTabBar: home, discover, markets, portfolio, money, settings.
const List<String> kTabOrder = [
  'home', 'discover', 'markets', 'portfolio', 'money', 'settings',
];

int _tabIndex(String id) => kTabOrder.indexOf(id).clamp(0, kTabOrder.length - 1);
String _tabId(int index) => kTabOrder[index.clamp(0, kTabOrder.length - 1)];

class _ShellState extends State<Shell> {
  String _tab = 'home';
  late Session _session = widget.session;
  List<dynamic> _orders = const [];
  String _sessionState = 'Closed';
  String _sessionNote = '';
  late final PageController _pageCtrl =
      PageController(initialPage: _tabIndex(_tab));

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadMeta();
    // A customer does not poll for much, but an incoming call has to arrive
    // without the app being open on a particular screen.
    _ring = Timer.periodic(const Duration(seconds: 5), (_) => _checkRinging());
  }

  Timer? _ring;
  bool _ringingShown = false;

  @override
  void dispose() {
    _ring?.cancel();
    super.dispose();
  }

  Future<void> _checkRinging() async {
    if (_ringingShown || !mounted) return;
    try {
      final r = await widget.api.get('call.pending');
      final rows = r is List ? r : const [];
      if (rows.isEmpty || !mounted) return;
      final c = Map<String, dynamic>.from(rows.first as Map);
      _ringingShown = true;
      final accept = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dc) => AlertDialog(
          title: const Text('Incoming call'),
          content: Text('${c['from']} is calling you.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dc).pop(false),
                child: const Text('Decline')),
            FilledButton(
                onPressed: () => Navigator.of(dc).pop(true),
                child: const Text('Answer')),
          ],
        ),
      );
      if (!mounted) { _ringingShown = false; return; }
      if (accept == true) {
        await widget.api.post('call.answer', {'id': c['id']});
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CallScreen(
            api: widget.api,
            callId: '${c['id']}',
            otherName: '${c['from']}',
            isCaller: false,
          ),
        ));
      } else {
        await widget.api.post('call.end', {'id': c['id']});
      }
      _ringingShown = false;
    } catch (_) {
      _ringingShown = false;
    }
  }

  /// Market session state for the Markets header. Open to everyone, so this
  /// works even before the portfolio arrives.
  Future<void> _loadMeta() async {
    try {
      final m = await widget.api.get('meta');
      final sess = (m is Map ? m['session'] : null);
      if (sess is Map && mounted) {
        setState(() {
          _sessionState = '${sess['state'] ?? 'Closed'}';
          _sessionNote = '${sess['note'] ?? ''}';
        });
      }
    } catch (_) {
      // The header falls back to "Closed".
    }
  }

  /// Open orders feed the Portfolio tab. A failure here leaves the list empty
  /// rather than blocking the shell.
  Future<void> _loadOrders() async {
    try {
      final rows = await widget.api.orders();
      if (mounted) setState(() => _orders = rows);
    } catch (_) {
      // The empty state stands.
    }
  }

  Future<void> _refresh() async {
    try {
      final s = Session.fromJson(await widget.api.me());
      if (mounted) setState(() => _session = s);
      await _loadOrders();
    } on ApiException {
      // Keep what is on screen rather than blanking it.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.p0,
      body: AnimatedBuilder(
        animation: widget.money,
        builder: (context, _) => Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              physics: const BouncingScrollPhysics(),
              itemCount: kTabOrder.length,
              onPageChanged: (i) => setState(() => _tab = _tabId(i)),
              itemBuilder: (context, i) => _bodyFor(kTabOrder[i]),
            ),
            VoiceFab(onTap: _openVoice),
          ],
        ),
      ),
      bottomNavigationBar: XTabBar(
        current: _tab,
        onTap: (id) {
          if (id == _tab) return;
          _pageCtrl.jumpToPage(_tabIndex(id));
          setState(() => _tab = id);
        },
      ),
    );
  }

  void _openTab(String id) {
    if (id == _tab) return;
    _pageCtrl.jumpToPage(_tabIndex(id));
    setState(() => _tab = id);
  }

  Widget _bodyFor(String id) {
    switch (id) {
      case 'home':
        return RefreshIndicator(
          onRefresh: _refresh,
          color: context.pal.act,
          child: HomeScreen(
            session: _session,
            money: widget.money,
            logoUrl: widget.api.logoUrl,
            onOpenTab: _openTab,
            api: widget.api,
            onChanged: _refresh,
          ),
        );
      case 'discover':
        return DiscoverScreen(
          money: widget.money,
          api: widget.api,
          available: _session.portfolio.balances.available,
        );
      case 'markets':
        return MarketsScreen(
          money: widget.money,
          sessionState: _sessionState,
          sessionNote: _sessionNote,
          logoUrl: widget.api.logoUrl,
          api: widget.api,
          available: _session.portfolio.balances.available,
        );
      case 'portfolio':
        return RefreshIndicator(
          onRefresh: _refresh,
          color: context.pal.act,
          child: PortfolioScreen(
            session: _session,
            money: widget.money,
            logoUrl: widget.api.logoUrl,
            orders: _orders,
            api: widget.api,
            onChanged: _refresh,
          ),
        );
      case 'money':
        return MoneyScreen(
          session: _session,
          money: widget.money,
          api: widget.api,
          onChanged: _refresh,
        );
      case 'settings':
        return SettingsScreen(
          session: _session,
          money: widget.money,
          api: widget.api,
          theme: widget.theme,
          onChanged: _refresh,
          onSignOut: () async {
            await widget.api.logout();
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('xflws_cookie');
            await prefs.remove('xflws_signed_in');
            if (context.mounted) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => SignInScreen(
                    api: widget.api,
                    money: widget.money,
                    theme: widget.theme),
              ));
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// (ticker, name) pairs the parser matches spoken words against. Built from
  /// the customer's own holdings, so "buy 50 cleopatra" resolves.
  List<(String, String)> get _universe => [
        for (final h in _session.portfolio.holdings)
          if (h.ticker.isNotEmpty) (h.ticker, h.name),
      ];

  void _openVoice() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.pal.p2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VoiceSheet(
        universe: _universe,
        currency: widget.money.code,
        onRun: _runIntent,
      ),
    );
  }

  /// Executes an intent and returns what should be spoken back.
  ///
  /// Anything that moves money only ever *opens* the relevant screen with the
  /// details filled in — the confirmation still happens there, where the fees
  /// and the balance are visible.
  String _runIntent(VoiceIntent it) {
    switch (it.kind) {
      case IntentKind.nav:
        setState(() => _tab = it.route ?? 'home');
        return it.say;

      case IntentKind.buy:
      case IntentKind.sell:
        final matches = _session.portfolio.holdings
            .where((x) => x.ticker == it.ticker)
            .toList();
        if (matches.isEmpty) return 'I could not find ${it.ticker}.';
        final h = matches.first;
        openSecurity(
          context,
          api: widget.api,
          money: widget.money,
          instrument: instrumentFromHolding(h),
          holding: h,
          available: _session.portfolio.balances.available,
          onChanged: _refresh,
          sessionState: _sessionState,
        );
        return '${it.say}. Check the cost and confirm on the ticket.';

      case IntentKind.transfer:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TransferScreen(
            money: widget.money,
            api: widget.api,
            available: _session.portfolio.balances.available,
            onDone: _refresh,
          ),
        ));
        return '${it.say}. Confirm the recipient before sending.';

      case IntentKind.withdraw:
      case IntentKind.deposit:
        setState(() => _tab = 'money');
        return it.say;

      case IntentKind.alert:
        setState(() => _tab = 'settings');
        return '${it.say}. Set it under price alerts.';

      case IntentKind.ask:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const AiScreen(),
        ));
        return 'Opening the assistant.';
    }
  }

}
