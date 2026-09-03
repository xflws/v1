// Discover, Money and Settings.
//
// Ported from `[data-scr="discover"]`, `[data-scr="money"]` and
// paintSettings(). The nav lists below carry the source's exact icons,
// titles and subtitles.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../data/models.dart';
import '../data/api.dart';
import '../core/theme_controller.dart';
import '../widgets/atoms.dart';
import '../widgets/nav_row.dart';
import 'cards.dart';
import 'transfer.dart';
import 'more_screens.dart';
import 'onboarding_settings.dart';
import 'settings_subscreens.dart';
import 'flows.dart';
import 'copy_trading.dart';

// ── Discover ─────────────────────────────────────────────────────────────

/// PRODUCTS — the four tiles at the top.
const List<(String, String, String)> kProducts = [
  ('Local currency funds', 'Egyptian pound', 'lcy'),
  ('Foreign currency funds', 'US dollar', 'fcy'),
  ('Metal funds', 'Gold and silver', 'metal'),
  ('Savings', 'Daily returns and goals', 'savings'),
];

/// COLLECTIONS.
const List<(String, String, IconData)> kCollections = [
  ('Health care', '2 stocks', Ph.firstAidKit),
  ('Sharia-compliant', '3 stocks', Ph.moonStars),
  ('EGX30 companies', '3 stocks', Ph.buildings),
  ('Dividend payers', '3 stocks', Ph.handCoins),
  ('Recently listed', '1 stock', Ph.sparkle),
  ('Most traded', '4 stocks', Ph.trendUp),
];

/// moreNav.
const List<(IconData, String, String)> kMoreNav = [
  (Ph.chartBar, 'Egyptian shares', '273 companies on the exchange'),
  (Ph.receipt, 'T-Bills and bonds', 'Government, sukuk and corporate debt'),
  (Ph.piggyBank, 'Savings and goals', 'Daily returns, goals and auto-saving'),
  (Ph.arrowsClockwise, 'Automatic saving', 'Plans that invest for you on a schedule'),
  (Ph.handCoins, 'Borrow and finance', 'Against holdings you already own'),
  (Ph.graduationCap, 'Learning hub', 'Short lessons and paper trading'),
  (Ph.userFocus, 'Expert advisory', 'Book a licensed adviser by the hour'),
  (Ph.copy, 'Copy trading', 'Follow another investor automatically'),
  (Ph.calculator, 'Investment calculator', 'See what regular investing becomes'),
];

/// helpNav.
const List<(IconData, String, String)> kHelpNav = [
  (Ph.usersThree, 'Community', 'See what other investors hold and say'),
  (Ph.sparkle, 'AI assistant', 'Ask about your portfolio'),
  (Ph.headset, 'Contact us', 'Chat, message or call'),
  (Ph.fileText, 'Request a statement', 'Email or certified copy'),
];

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    required this.money,
    this.api,
    this.available = 0,
  });

  final Money money;
  final Api? api;
  final num available;

  void _go(BuildContext context, String title) {
    final builders = <String, WidgetBuilder>{
      'Egyptian shares': (_) => SearchScreen(
        api: api!, money: money, available: available,
      ),
      'T-Bills and bonds': (_) => TbillsScreen(money: money),
      'Savings and goals': (_) => SavingsScreen(money: money),
      'Learning hub': (_) => const LearnScreen(),
      'Investment calculator': (_) => CalculatorScreen(money: money),
      'Community': (_) => const CommunityScreen(),
      'Copy trading': (_) => CopyTradingScreen(api: api!, money: money),
      'AI assistant': (_) => const AiScreen(),
      'Automatic saving': (_) => AutosaveScreen(money: money),
      'Expert advisory': (_) => ExpertScreen(money: money),
      'Borrow and finance': (_) => LendingScreen(money: money, api: api),
      'Contact us': (_) => const ContactScreen(),
      'Request a statement': (_) => const StatementScreen(),
    };
    final b = builders[title];
    if (b != null) Navigator.of(context).push(MaterialPageRoute(builder: b));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.p0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discover',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: pal.ink,
                          )),
                      Opacity(
                        opacity: .65,
                        child: SvgPicture.asset(
                            'assets/brand/wordmark.svg',
                            height: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // The search field is a button, not an input — it opens the
                  // search screen.
                  GestureDetector(
                    onTap: api == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SearchScreen(
                                api: api!,
                                money: money,
                                available: available,
                              ),
                            )),
                    child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: pal.p1,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(Ph.magnifyingGlass, size: 16, color: pal.mute),
                        const SizedBox(width: 10),
                        Text('Search stocks, funds, bills',
                            style:
                                TextStyle(fontSize: 13, color: pal.mute)),
                      ],
                    ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.35,
                  children: [
                    for (final p in kProducts) _productTile(context, p),
                  ],
                ),
                const SectionLabel('More ways to invest'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < kMoreNav.length; i++)
                        NavRow(
                          icon: kMoreNav[i].$1,
                          title: kMoreNav[i].$2,
                          subtitle: kMoreNav[i].$3,
                          first: i == 0,
                          onTap: () => _go(context, kMoreNav[i].$2),
                        ),
                    ],
                  ),
                ),
                const SectionLabel('Collections'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  // 2.6 rather than 3.1: the name and count need two full
                  // lines at Cairo's metrics.
                  childAspectRatio: 2.6,
                  children: [
                    for (final c in kCollections) _collectionTile(context, c),
                  ],
                ),
                const SectionLabel('Help and tools'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < kHelpNav.length; i++)
                        NavRow(
                          icon: kHelpNav[i].$1,
                          title: kHelpNav[i].$2,
                          subtitle: kHelpNav[i].$3,
                          first: i == 0,
                          onTap: () => _go(context, kHelpNav[i].$2),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTile(BuildContext context, (String, String, String) p) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.p1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _prodArt(context, p.$3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.$1,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: pal.ink,
                  )),
              Text(p.$2,
                  style: TextStyle(fontSize: 11, color: pal.mute)),
            ],
          ),
        ],
      ),
    );
  }

  /// prodArt — the small inline illustrations, transcribed from the source.
  Widget _prodArt(BuildContext context, String key) {
    final pal = context.pal;
    final gain = _hex(pal.gain), act = _hex(pal.act), ink = _hex(pal.ink);
    final svg = switch (key) {
      'fcy' => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 48">'
          '<circle cx="24" cy="24" r="15" fill="$gain" opacity=".16"/>'
          '<circle cx="24" cy="24" r="15" fill="none" stroke="$gain" stroke-width="2.5"/>'
          '<text x="24" y="31" text-anchor="middle" font-size="19" '
          'font-weight="700" fill="$gain">\$</text></svg>',
      'metal' => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 48">'
          '<path d="M14 30h22l4 12H10z" fill="$act" opacity=".65"/>'
          '<path d="M30 30h22l4 12H26z" fill="$act"/>'
          '<path d="M22 16h22l4 12H18z" fill="$act" opacity=".85"/></svg>',
      'lcy' => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 48">'
          '<circle cx="26" cy="24" r="15" fill="$ink"/>'
          '<circle cx="40" cy="24" r="15" fill="$gain" opacity=".85"/></svg>',
      _ => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 48">'
          '<rect x="10" y="16" width="44" height="26" rx="8" fill="$gain"/>'
          '<circle cx="44" cy="26" r="2.5" fill="#fff"/>'
          '<path d="M22 16v-4a10 10 0 0120 0v4" fill="none" stroke="$ink" '
          'stroke-width="3"/></svg>',
    };
    return SvgPicture.string(svg, width: 64, height: 48);
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Widget _collectionTile(
      BuildContext context, (String, String, IconData) c) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.p2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pal.tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(c.$3, size: 18, color: pal.actDk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: pal.ink,
                    )),
                Text(c.$2,
                    style: TextStyle(fontSize: 10.5, color: pal.mute)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Money ────────────────────────────────────────────────────────────────

/// BILLS — the eight billers.
const List<(IconData, String)> kBills = [
  (Ph.deviceMobile, 'Mobile'),
  // ph-router does not exist in Phosphor; the source uses broadcast for ADSL.
  (Ph.broadcast, 'ADSL'),
  (Ph.phone, 'Landline'),
  (Ph.lightning, 'Electricity'),
  (Ph.television, 'TV'),
  (Ph.drop, 'Water'),
  (Ph.graduationCap, 'Tuition'),
  (Ph.car, 'Traffic'),
];

class MoneyScreen extends StatelessWidget {
  const MoneyScreen({
    super.key,
    required this.session,
    required this.money,
    required this.api,
    this.onChanged,
  });

  final Session session;
  final Money money;
  final Api api;
  final VoidCallback? onChanged;

  void _flow(BuildContext context, String kind, {String biller = 'Mobile'}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MoneyFlowScreen(
          kind: kind,
          money: money,
          api: api,
          available: session.portfolio.balances.available,
          biller: biller,
          onDone: onChanged,
        ),
      ));

  void _openCards(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CardsScreen(
          money: money,
          api: api,
          onChanged: onChanged,
        ),
      ));

  void _openTransfer(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransferScreen(
          money: money,
          api: api,
          available: session.portfolio.balances.available,
          onDone: onChanged,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.p0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _wallet(context),
          _cardOffer(context),
          _divider(context),
          _bills(context),
          _divider(context),
          _transactions(context),
          _divider(context),
          _install(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.pal.line);

  /// The ink header. Shows `available`, not the ledger balance — held funds
  /// are committed to pending orders and are not spendable.
  Widget _wallet(BuildContext context) {
    final pal = context.pal;
    const actions = [
      (Ph.plus, 'Add'),
      (Ph.arrowLineDown, 'Withdraw'),
      (Ph.arrowsLeftRight, 'Transfer'),
    ];

    return Container(
      color: pal.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wallet balance',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: .70),
                  )),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(money.code,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: .80),
                      )),
                  const SizedBox(width: 6),
                  Text(
                    money.format(session.portfolio.balances.available,
                        decimals: 2),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (session.portfolio.balances.held > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${money.format(session.portfolio.balances.held, decimals: 2)} '
                  'held against pending orders',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: .60),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (actions[i].$2 == 'Transfer') {
                            _openTransfer(context);
                          } else {
                            _flow(context,
                                actions[i].$2 == 'Add' ? 'deposit' : 'withdraw');
                          }
                        },
                        child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(actions[i].$1, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(actions[i].$2,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white,
                                )),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardOffer(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.p1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // The stacked-cards illustration, transcribed from the source SVG.
            SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 90 58">'
              '<rect x="10" y="2" width="78" height="50" rx="7" fill="${DiscoverScreen._hex(pal.act)}"/>'
              '<rect x="2" y="6" width="78" height="50" rx="7" fill="${DiscoverScreen._hex(pal.ink)}"/>'
              '<rect x="11" y="18" width="15" height="11" rx="2.5" fill="${DiscoverScreen._hex(pal.act)}"/>'
              '<rect x="11" y="41" width="34" height="3" rx="1.5" fill="#fff" opacity=".45"/>'
              '<circle cx="66" cy="42" r="7" fill="#fff" opacity=".28"/>'
              '<circle cx="73" cy="42" r="7" fill="#fff" opacity=".28"/></svg>',
              width: 90,
              height: 58,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('XFLWS card',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: pal.ink,
                      )),
                  const SizedBox(height: 2),
                  Text('Free to order. Arrives in 3 days.',
                      style: TextStyle(
                          fontSize: 11, height: 1.375, color: pal.mute)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openCards(context),
                    child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: pal.act,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Manage cards',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        )),
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

  Widget _bills(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pay your bills',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: pal.ink,
              )),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
            children: [
              for (final b in kBills)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _flow(context, 'bill', biller: b.$2),
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: pal.p1, shape: BoxShape.circle),
                      child: Icon(b.$1, size: 20, color: pal.actDk),
                    ),
                    const SizedBox(height: 6),
                    Text(b.$2,
                        style:
                            TextStyle(fontSize: 10.5, color: pal.mute)),
                  ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactions(BuildContext context) =>
      _TransactionList(api: api, money: money);

  Widget _install(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal.p1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Ph.deviceMobile, size: 21, color: pal.actDk),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Install XFLWS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: pal.ink,
                      )),
                  Text('Full screen, works offline',
                      style: TextStyle(
                          fontSize: 11, height: 1.375, color: pal.mute)),
                ],
              ),
            ),
            Icon(Ph.caretRight, size: 13, color: pal.mute),
          ],
        ),
      ),
    );
  }
}

// ── Settings ─────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.money,
    this.api,
    this.theme,
    this.onSignOut,
    this.onChanged,
  });

  final Session session;
  final Money money;
  final Api? api;
  final ThemeController? theme;
  final VoidCallback? onSignOut;
  final VoidCallback? onChanged;

  void _push(BuildContext context, WidgetBuilder b) =>
      Navigator.of(context).push(MaterialPageRoute(builder: b));

  static const String _avatarSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 44 44">
  <circle cx="22" cy="22" r="22" fill="#DDE5F0"/>
  <circle cx="22" cy="17" r="7" fill="#8FA3BF"/>
  <path d="M6 42c1.6-9 8-13.5 16-13.5S36.4 33 38 42z" fill="#8FA3BF"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      color: pal.p0,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text('Settings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: pal.ink,
                  )),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SvgPicture.asset('assets/brand/wordmark.svg',
                        height: 22),
                  ),
                ),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipOval(
                          child: SvgPicture.string(_avatarSvg,
                              width: 48, height: 48),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(session.user.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: pal.ink,
                                  )),
                              Text(
                                session.user.kycTier >= 2
                                    ? 'Verified \u00B7 ${session.user.handle}'
                                    : 'Unverified \u00B7 ${session.user.handle}',
                                style: TextStyle(
                                    fontSize: 11.5, color: pal.mute),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SectionLabel('Account'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    _row(Ph.bell, 'Notifications', 'On', true,
                        onTap: () => _push(
                            context, (_) => NotificationsScreen(api: api))),
                    _row(Ph.shieldCheck, 'Security', 'PIN, 2FA, devices', false,
                        onTap: () => _push(
                            context,
                            (_) => SecuritySettingsScreen(
                                handle: session.user.handle))),
                    _row(Ph.sliders, 'Preferences',
                        'Style, language, currencies', false,
                        onTap: () => _push(
                            context,
                            (_) => PreferencesScreen(
                                money: money, theme: theme))),
                    _row(Ph.identificationCard, 'Identity verification',
                        session.user.kycTier >= 2 ? 'Verified' : 'Pending', false,
                        onTap: () => _push(context,
                            (_) => KycScreen(
                                  name: session.user.name,
                                  api: api,
                                  onDone: onChanged,
                                ))),
                    _row(Ph.fileText, 'Request a statement', '', false,
                        onTap: () =>
                            _push(context, (_) => const StatementScreen())),
                    _row(Ph.lockKey, 'Lock the app now', '', false,
                        onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('App lock requires biometrics setup.')),
                      );
                    }),
                  ]),
                ),
                const SectionLabel('Accounts and reporting'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    _row(Ph.squaresFour, 'Sub-accounts', '3', true,
                        onTap: () => _push(
                            context, (_) => SubAccountsScreen(money: money))),
                    _row(Ph.users, 'Family accounts', '2', false,
                        onTap: () =>
                            _push(context, (_) => const FamilyScreen())),
                    _row(Ph.bell, 'Price alerts', '3', false,
                        onTap: () => _push(
                            context, (_) => AlertsScreen(money: money, api: api))),
                    _row(Ph.chartLine, 'Reports', '', false,
                        onTap: () =>
                            _push(context, (_) => ReportsScreen(money: money))),
                  ]),
                ),
                const SectionLabel('Support'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(children: [
                    _row(Ph.headset, 'Contact us', '', true,
                        onTap: () => _push(context, (_) => const ContactScreen())),
                    _row(Ph.scales, 'Legal and documents', '', false,
                        onTap: () =>
                            _push(context, (_) => const LegalScreen())),
                    _row(Ph.signOut, 'Sign out', '', false, onTap: onSignOut),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('XFLWS \u00B7 version 1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: pal.mute)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData ic, String label, String value, bool first,
          {VoidCallback? onTap}) =>
      NavRow(
        icon: ic,
        title: label,
        trailingText: value.isEmpty ? null : value,
        first: first,
        iconSize: 36,
        onTap: onTap,
      );
}

/// Transaction list loaded from the API, shown on the Money tab.
class _TransactionList extends StatefulWidget {
  const _TransactionList({required this.api, required this.money});

  final Api api;
  final Money money;

  @override
  State<_TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<_TransactionList> {
  List<dynamic> _txns = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.transactions();
      if (mounted) setState(() {
        _txns = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Transactions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: pal.ink,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: _loading ? null : _load,
                child: Icon(Ph.arrowsClockwise, size: 16, color: pal.mute),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_txns.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: pal.p1,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('No transactions yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: pal.mute)),
            )
          else
            InnerCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _txns.length; i++)
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
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _txnColour(_txns[i]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _txnIcon(_txns[i]),
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_txnLabel(_txns[i]),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: pal.ink,
                                    )),
                                Text(_txnDate(_txns[i]),
                                    style: TextStyle(
                                        fontSize: 11, color: pal.mute)),
                              ],
                            ),
                          ),
                          Text(
                            _txnAmount(_txns[i]),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _txnAmountUp(_txns[i])
                                  ? pal.gain
                                  : pal.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _txnColour(dynamic t) {
    final kind = '${t['kind'] ?? ''}'.toLowerCase();
    final pal = context.pal;
    if (kind == 'deposit') return const Color(0xFF2B2B2B);
    if (kind == 'withdrawal') return const Color(0xFFB5121B);
    if (kind == 'transfer') return const Color(0xFF1F6FB2);
    if (kind == 'bill') return const Color(0xFFE4610F);
    return pal.mute;
  }

  IconData _txnIcon(dynamic t) {
    final kind = '${t['kind'] ?? ''}'.toLowerCase();
    if (kind == 'deposit') return Ph.arrowLineDown;
    if (kind == 'withdrawal') return Ph.arrowsDownUp;
    if (kind == 'transfer') return Ph.arrowsLeftRight;
    if (kind == 'bill') return Ph.receipt;
    return Ph.receipt;
  }

  String _txnLabel(dynamic t) {
    final kind = '${t['kind'] ?? ''}';
    final method = '${t['method'] ?? t['biller'] ?? ''}';
    final status = '${t['status'] ?? ''}';
    return '${kind[0].toUpperCase()}${kind.substring(1)}${method.isNotEmpty ? ' · $method' : ''}${status.isNotEmpty ? ' · $status' : ''}';
  }

  String _txnDate(dynamic t) {
    final at = '${t['at'] ?? ''}';
    if (at.isEmpty) return '';
    try {
      final d = DateTime.parse(at);
      return '${d.day} ${_month(d.month)} ${d.year}';
    } catch (_) {
      return at;
    }
  }

  String _month(int m) => const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][(m - 1).clamp(0, 11)];

  String _txnAmount(dynamic t) {
    final amount = t['amount'];
    final n = amount is num ? amount : num.tryParse('$amount') ?? 0;
    return '${widget.money.format(n)} ${widget.money.code}';
  }

  bool _txnAmountUp(dynamic t) {
    final kind = '${t['kind'] ?? ''}'.toLowerCase();
    return kind == 'deposit';
  }
}
