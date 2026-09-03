// The last screens: KYC onboarding, Security, Preferences, Automatic saving
// and Expert advisory.
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/money.dart';
import '../core/ph.dart';
import '../widgets/atoms.dart';
import 'more_screens.dart' show PushedHeader;
import '../data/api.dart';
import '../core/theme_controller.dart';

Widget _cap(BuildContext context, String s, {double top = 16}) => Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 4),
      child: Text(s, style: TextStyle(fontSize: 12, color: context.pal.mute)),
    );

Widget _foot(BuildContext context, String label, VoidCallback? onTap) {
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
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? .45 : 1,
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

/// The radio-style option row shared by KYC and copy trading.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.first = false,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border(
            top: first ? BorderSide.none : BorderSide(color: pal.line),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? pal.tint : pal.p1,
                shape: BoxShape.circle,
              ),
              child: Icon(selected ? Ph.checkCircle : Ph.circle,
                  size: 18, color: selected ? pal.actDk : pal.mute),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: pal.ink,
                      )),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(fontSize: 11, color: pal.mute)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── KYC ──────────────────────────────────────────────────────────────────

const List<String> kKycSteps = [
  'Account type',
  'Identity',
  'Risk profile',
  'Review'
];

class KycScreen extends StatefulWidget {
  const KycScreen({super.key, required this.name, this.api, this.onDone});

  final String name;
  final Api? api;
  final VoidCallback? onDone;

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  int _step = 0;
  String _type = 'Individual';
  String _idType = 'National ID';
  String _risk = 'Balanced';

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _step == 0
                            ? Navigator.of(context).maybePop()
                            : setState(() => _step--),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Open your account',
                                style: TextStyle(
                                  fontSize: 17,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  color: pal.ink,
                                )),
                            Text(
                              'Step ${_step + 1} of ${kKycSteps.length} \u00B7 '
                              '${kKycSteps[_step]}',
                              style: TextStyle(
                                  fontSize: 11.5, color: pal.mute),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < kKycSteps.length; i++) ...[
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _step ? pal.act : pal.p1,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        if (i < kKycSteps.length - 1)
                          const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [_body(context)],
            ),
          ),
          _foot(
            context,
            _step == kKycSteps.length - 1 ? 'Submit application' : 'Continue',
            () {
              if (_step < kKycSteps.length - 1) {
                setState(() => _step++);
              } else {
                _submit();
              }
            },
          ),
        ],
      ),
    );
  }

  /// The server decides: auto-approve, wait on a simulated provider, or queue
  /// for a person. The message reports which, rather than always claiming
  /// review.
  Future<void> _submit() async {
    final api = widget.api;
    if (api == null) {
      Navigator.of(context).pop();
      return;
    }
    try {
      final r = await api.submitKyc(
        accountType: _type,
        documentType: _idType,
        riskProfile: _risk,
      );
      final state = '${(r['application'] as Map?)?['state'] ?? 'pending'}';
      widget.onDone?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state == 'approved'
            ? 'Verified. You can fund the account and place orders.'
            : 'Submitted. We will let you know when it is reviewed.'),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _body(BuildContext context) => switch (_step) {
        0 => _typeStep(context),
        1 => _idStep(context),
        2 => _riskStep(context),
        _ => _reviewStep(context),
      };

  Widget _typeStep(BuildContext context) {
    const opts = [
      ('Individual', 'One holder, fastest to open'),
      ('Joint', 'Two holders'),
      ('Corporate', 'Company or institution'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cap(context, 'Who is this account for?'),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < opts.length; i++)
                OptionRow(
                  label: opts[i].$1,
                  subtitle: opts[i].$2,
                  selected: _type == opts[i].$1,
                  first: i == 0,
                  onTap: () => setState(() => _type = opts[i].$1),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You must be 21 or older and hold a valid Egyptian national ID or '
          'passport. Opening an account is free.',
          style: TextStyle(
              fontSize: 11.5, height: 1.375, color: context.pal.mute),
        ),
      ],
    );
  }

  Widget _idStep(BuildContext context) {
    final pal = context.pal;
    const docs = [
      ('National ID', 'Front and back'),
      ('Passport', 'Photo page'),
    ];
    const uploads = ['Front of document', 'Back of document', 'Selfie'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cap(context, 'Document type'),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < docs.length; i++)
                OptionRow(
                  label: docs[i].$1,
                  subtitle: docs[i].$2,
                  selected: _idType == docs[i].$1,
                  first: i == 0,
                  onTap: () => setState(() => _idType = docs[i].$1),
                ),
            ],
          ),
        ),
        _cap(context, 'Upload'),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < uploads.length; i++)
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
                          color: pal.p1,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(Ph.camera, size: 18, color: pal.mute),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(uploads[i],
                            style: TextStyle(
                                fontSize: 13.5, color: pal.ink)),
                      ),
                      Text('Upload',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: pal.actDk,
                          )),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Camera capture is not wired: the `camera` package and platform
        // permission flows are needed, and a fake success here would let an
        // unverified account through onboarding.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Ph.info, size: 14, color: pal.actDk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Document capture is not connected in this build. Wire it to '
                  'the camera and the custodian\u2019s verification API before '
                  'release \u2014 do not let this step pass without a real check.',
                  style: TextStyle(
                      fontSize: 11.5, height: 1.375, color: pal.actDk),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your documents are checked by the FRA-registered custodian. '
          'Verification usually takes under an hour.',
          style: TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
        ),
      ],
    );
  }

  Widget _riskStep(BuildContext context) {
    const opts = [
      ('Conservative', 'Protect capital, accept lower returns'),
      ('Balanced', 'Some risk for steady growth'),
      ('Growth', 'Accept large swings for higher returns'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cap(context, 'How would you describe your approach?'),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < opts.length; i++)
                OptionRow(
                  label: opts[i].$1,
                  subtitle: opts[i].$2,
                  selected: _risk == opts[i].$1,
                  first: i == 0,
                  onTap: () => setState(() => _risk = opts[i].$1),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'This sets the products you can access. You can retake the '
          'assessment at any time.',
          style: TextStyle(
              fontSize: 11.5, height: 1.375, color: context.pal.mute),
        ),
      ],
    );
  }

  Widget _reviewStep(BuildContext context) {
    final pal = context.pal;
    final lines = [
      ('Account type', _type),
      ('Document', _idType),
      ('Risk profile', _risk),
      ('Name', widget.name),
      ('Nationality', 'Egyptian'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cap(context, 'Review'),
        InnerCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < lines.length; i++)
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(lines[i].$1,
                          style:
                              TextStyle(fontSize: 13, color: pal.mute)),
                      Text(lines[i].$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: pal.ink,
                          )),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'By continuing you agree to the client agreement, the risk '
          'disclosure and the FRA terms of business.',
          style: TextStyle(fontSize: 11.5, height: 1.375, color: pal.mute),
        ),
      ],
    );
  }
}

// ── Security ─────────────────────────────────────────────────────────────

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key, required this.handle});

  final String handle;

  @override
  State<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _pin = true;
  bool _bio = false;
  bool _twofa = true;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Security', subtitle: 'PIN, 2FA and devices'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cap(context, 'Sign in'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _toggle(context, Ph.password, 'App PIN',
                          'Six digits, asked on every launch', _pin, true,
                          (v) => setState(() => _pin = v)),
                      _toggle(context, Ph.fingerprint, 'Biometric unlock',
                          'Face or fingerprint instead of the PIN', _bio, false,
                          (v) => setState(() => _bio = v)),
                      _toggle(context, Ph.shieldCheck,
                          'Two-factor authentication',
                          'SMS code on new devices and withdrawals', _twofa,
                          false, (v) => setState(() => _twofa = v)),
                    ],
                  ),
                ),
                _cap(context, 'Contact details'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _row(context, Ph.deviceMobile, 'Mobile number',
                          '+20 10 \u2022\u2022\u2022\u2022 4821', true),
                      _row(context, Ph.envelope, 'Email',
                          'a\u2022\u2022\u2022@gmail.com', false),
                      _row(context, Ph.user, 'Username', widget.handle, false),
                    ],
                  ),
                ),
                _cap(context, 'Devices'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _row(context, Ph.deviceMobile, 'This device',
                          'Active now', true),
                      _row(context, Ph.desktop, 'Chrome on Windows',
                          '2 days ago', false),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Signing out a device revokes its session immediately. If '
                  'you do not recognise one, sign it out and change your '
                  'password.',
                  style: TextStyle(
                      fontSize: 11.5, height: 1.375, color: pal.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(BuildContext context, IconData ic, String label, String sub,
      bool on, bool first, ValueChanged<bool> onChanged) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: first ? BorderSide.none : BorderSide(color: pal.line),
        ),
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
            child: Icon(ic, size: 17, color: pal.actDk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 13.5, color: pal.ink)),
                Text(sub,
                    style: TextStyle(fontSize: 11, color: pal.mute)),
              ],
            ),
          ),
          Switch(
            value: on,
            thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? Colors.white
                  : pal.p2,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? pal.act : pal.p1,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData ic, String label, String value,
      bool first) {
    final pal = context.pal;
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
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pal.tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ic, size: 17, color: pal.actDk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13.5, color: pal.ink)),
          ),
          Text(value,
              style: TextStyle(fontSize: 12.5, color: pal.mute)),
          const SizedBox(width: 8),
          Icon(Ph.caretRight, size: 13, color: pal.mute),
        ],
      ),
    );
  }
}

// ── Preferences ──────────────────────────────────────────────────────────

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key, required this.money, this.theme});

  final Money money;
  final ThemeController? theme;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late String _hero = widget.theme?.style ?? 'white';
  bool _voice = true;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const styles = [
      ('white', 'White', Color(0xFFFFFFFF)),
      ('cream', 'Beige', Color(0xFFF6E7D8)),
      ('navy', 'Navy', Color(0xFF062E54)),
    ];

    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Preferences',
              subtitle: 'Style, language and currencies'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cap(context, 'Interface'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Card style',
                            style:
                                TextStyle(fontSize: 13, color: pal.ink)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (var i = 0; i < styles.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _hero = styles[i].$1);
                                    // Repaints the whole app and persists.
                                    widget.theme?.select(styles[i].$1);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _hero == styles[i].$1
                                            ? pal.act
                                            : pal.line,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: styles[i].$3,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: pal.line),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(styles[i].$2,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: pal.ink)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Applies immediately and is remembered.',
                          style: TextStyle(
                              fontSize: 11, height: 1.375, color: pal.mute),
                        ),
                      ],
                    ),
                  ),
                ),
                _cap(context, 'Currency'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < widget.money.all.length; i++)
                        InkWell(
                          onTap: () => setState(() =>
                              widget.money.select(widget.money.all[i].code)),
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
                                Expanded(
                                  child: Text(
                                    '${widget.money.all[i].code} \u2014 '
                                    '${widget.money.all[i].name}',
                                    style: TextStyle(
                                        fontSize: 13.5, color: pal.ink),
                                  ),
                                ),
                                if (widget.money.all[i].code ==
                                    widget.money.code)
                                  Icon(Ph.check, size: 16, color: pal.act),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!widget.money.isLive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Rates are indicative, not live.',
                      style: TextStyle(fontSize: 11.5, color: pal.mute),
                    ),
                  ),
                _cap(context, 'Voice assistant'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                          child: Icon(Ph.microphone,
                              size: 17, color: pal.actDk),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Voice commands',
                                  style: TextStyle(
                                      fontSize: 13.5, color: pal.ink)),
                              Text('Not connected in this build',
                                  style: TextStyle(
                                      fontSize: 11, color: pal.mute)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _voice,
                          thumbColor: WidgetStateProperty.resolveWith(
                            (s) => s.contains(WidgetState.selected)
                                ? Colors.white
                                : pal.p2,
                          ),
                          trackColor: WidgetStateProperty.resolveWith(
                            (s) => s.contains(WidgetState.selected)
                                ? pal.act
                                : pal.p1,
                          ),
                          onChanged: (v) => setState(() => _voice = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Automatic saving ─────────────────────────────────────────────────────

const List<(String, String, num, IconData, bool)> kPlans = [
  ('Monthly into AZEQ', 'Every month \u00B7 1st', 2000, Ph.chartPieSlice, true),
  ('Weekly gold', 'Every week \u00B7 Sunday', 250, Ph.coins, true),
  ('Round-ups', 'On every card payment', 0, Ph.arrowsClockwise, false),
];

class AutosaveScreen extends StatelessWidget {
  const AutosaveScreen({super.key, required this.money});

  final Money money;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    // Weekly plans count four times a month, as the source computes.
    final total = kPlans
        .where((p) => p.$5 && p.$3 > 0)
        .fold<num>(0, (a, p) => a + (p.$2.startsWith('Every week') ? p.$3 * 4 : p.$3));
    final active = kPlans.where((p) => p.$5).length;

    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Automatic saving',
              subtitle: 'Plans that invest for you on a schedule'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invested automatically each month',
                            style:
                                TextStyle(fontSize: 11, color: pal.mute)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              money.format(total),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: pal.ink,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(money.code,
                                style: TextStyle(
                                    fontSize: 13, color: pal.mute)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Across $active active plans',
                            style: TextStyle(
                                fontSize: 11.5, color: pal.mute)),
                      ],
                    ),
                  ),
                ),
                _cap(context, 'Your plans'),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < kPlans.length; i++)
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
                                  color: pal.tint,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(kPlans[i].$4,
                                    size: 18, color: pal.actDk),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(kPlans[i].$1,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: pal.ink,
                                        )),
                                    Text(kPlans[i].$2,
                                        style: TextStyle(
                                            fontSize: 11, color: pal.mute)),
                                  ],
                                ),
                              ),
                              if (kPlans[i].$3 > 0)
                                Text(
                                  money.format(kPlans[i].$3),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: pal.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Pill(
                                text: kPlans[i].$5 ? 'On' : 'Off',
                                tone: kPlans[i].$5
                                    ? Tone.gain(context)
                                    : Tone.mute(context),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'A plan buys on schedule whatever the price. That is the '
                  'point \u2014 it removes the timing decision \u2014 but it '
                  'also buys into falling markets, so keep the amount to what '
                  'you can leave alone.',
                  style: TextStyle(
                      fontSize: 11.5, height: 1.375, color: pal.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expert advisory ──────────────────────────────────────────────────────

const List<(String, String, String, String, int)> kExperts = [
  ('Dr. Layla Mansour', 'Portfolio strategy \u00B7 14 years', '1,500', 'L',
      0xFF062E54),
  ('Karim Fahmy', 'Equity research \u00B7 9 years', '1,200', 'K', 0xFF0E7C5A),
  ('Nour El-Din', 'Retirement planning \u00B7 11 years', '1,000', 'N',
      0xFF5B3A8E),
];

class ExpertScreen extends StatelessWidget {
  const ExpertScreen({super.key, required this.money});

  final Money money;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: pal.p0,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const PushedHeader(
              title: 'Expert advisory',
              subtitle: 'Book a licensed adviser by the hour'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Text(
                    'Licensed advisers you can book by the hour. Separate from '
                    'your account manager, and independent of XFLWS product '
                    'sales.',
                    style: TextStyle(
                        fontSize: 11.5, height: 1.375, color: pal.mute),
                  ),
                ),
                InnerCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < kExperts.length; i++)
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
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Color(kExperts[i].$5),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(kExperts[i].$4,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    )),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(kExperts[i].$1,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: pal.ink,
                                        )),
                                    Text(kExperts[i].$2,
                                        style: TextStyle(
                                            fontSize: 11, color: pal.mute)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${kExperts[i].$3} ${money.code}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: pal.ink,
                                      )),
                                  Text('an hour',
                                      style: TextStyle(
                                          fontSize: 10, color: pal.mute)),
                                ],
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
        ],
      ),
    );
  }
}
