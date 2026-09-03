// Ported verbatim from the PAL / HERO objects in index.html.
// The web build locks itself to: pal='bridge', sky='photo', hero='white', light.
import 'package:flutter/material.dart';

@immutable
class Pal {
  const Pal({
    required this.ink,
    required this.act,
    required this.actDk,
    required this.tint,
    required this.gain,
    required this.loss,
    required this.p0,
    required this.p1,
    required this.p2,
    required this.mute,
    required this.line,
    required this.cream,
  });

  /// Primary text / deep brand navy.
  final Color ink;

  /// Accent — the orange every primary action uses.
  final Color act;

  /// Accent, darkened for text on light paper (contrast).
  final Color actDk;

  /// Faint accent wash behind selected chips.
  final Color tint;

  /// Up / profit.
  final Color gain;

  /// Down / loss.
  final Color loss;

  /// Paper 0 — the app background.
  final Color p0;

  /// Paper 1 — recessed panels inside a card.
  final Color p1;

  /// Paper 2 — raised cards.
  final Color p2;

  /// Secondary text.
  final Color mute;

  /// Hairline dividers and borders.
  final Color line;

  /// Cream hero variant.
  final Color cream;

  static const Pal bridgeLight = Pal(
    ink: Color(0xFF062E54),
    act: Color(0xFFFB721C),
    actDk: Color(0xFFC4530A),
    tint: Color(0xFFFEEFE3),
    gain: Color(0xFF006B61),
    loss: Color(0xFFA8192A),
    p0: Color(0xFFF4F2EF),
    p1: Color(0xFFFAF8F6),
    p2: Color(0xFFFFFFFF),
    mute: Color(0xFF7D8480),
    line: Color(0x1F062E54), // rgba(6,46,84,.12)
    cream: Color(0xFFF6E7D8),
  );

  static const Pal bridgeDark = Pal(
    ink: Color(0xFF04213D),
    act: Color(0xFFFF8A3D),
    actDk: Color(0xFFFF8A3D),
    tint: Color(0xFF3A2415),
    gain: Color(0xFF2FA893),
    loss: Color(0xFFE2726F),
    p0: Color(0xFF0C1211),
    p1: Color(0xFF131A1C),
    p2: Color(0xFF182126),
    mute: Color(0xFF8B9995),
    line: Color(0x1AFFFFFF), // rgba(255,255,255,.10)
    cream: Color(0xFF241C15),
  );

  static const Pal deckLight = Pal(
    ink: Color(0xFF062E54),
    act: Color(0xFFFB721C),
    actDk: Color(0xFFC4530A),
    tint: Color(0xFFFEEFE3),
    gain: Color(0xFF1E8E3E),
    loss: Color(0xFFA8192A),
    p0: Color(0xFFF5F1EC),
    p1: Color(0xFFFBF7F3),
    p2: Color(0xFFFFFFFF),
    mute: Color(0xFF7D7A74),
    line: Color(0x1F062E54),
    cream: Color(0xFFF6E7D8),
  );

  static const Pal currentLight = Pal(
    ink: Color(0xFF10201E),
    act: Color(0xFFC17F24),
    actDk: Color(0xFF9A5F0A),
    tint: Color(0xFFFDF3E7),
    gain: Color(0xFF006B61),
    loss: Color(0xFFA8192A),
    p0: Color(0xFFF1F3F2),
    p1: Color(0xFFF7F8F8),
    p2: Color(0xFFFFFFFF),
    mute: Color(0xFF7C8986),
    line: Color(0x1A10201E),
    cream: Color(0xFFF6E7D8),
  );
}

/// The hero card treatment. The build ships `white`.
@immutable
class Hero_ {
  const Hero_({
    required this.hbg,
    required this.hfg,
    required this.chart,
    required this.hchip,
    required this.chipOn,
    required this.chipOff,
    required this.chipTx,
  });

  final Color hbg;
  final Color hfg;
  final Color chart;
  final Color hchip;
  final Color chipOn;
  final Color chipOff;
  final Color chipTx;

  /// hero='white' — resolved against Pal.bridgeLight.
  static const Hero_ white = Hero_(
    hbg: Color(0xFFFFFFFF), // var(--p2)
    hfg: Color(0xFF062E54), // var(--ink)
    chart: Color(0xFF5A6773),
    hchip: Color(0xFFF4F2EF), // var(--p0)
    chipOn: Color(0xFFE4E8EB),
    chipOff: Color(0xFFF2F4F5),
    chipTx: Color(0xFF43505C),
  );

  static const Hero_ navy = Hero_(
    hbg: Color(0xFF062E54),
    hfg: Color(0xFFFFFFFF),
    chart: Color(0xFFFFFFFF),
    hchip: Color(0x24FFFFFF),
    chipOn: Color(0x3DFFFFFF),
    chipOff: Color(0x12FFFFFF),
    chipTx: Color(0xFFFFFFFF),
  );

  static const Hero_ cream = Hero_(
    hbg: Color(0xFFF6E7D8),
    hfg: Color(0xFF062E54),
    chart: Color(0xFF96602C),
    hchip: Color(0x1A96602C),
    chipOn: Color(0x3396602C),
    chipOff: Color(0x1296602C),
    chipTx: Color(0xFF6E441C),
  );
}

/// Makes [Pal] and [Hero_] reachable from any widget, the way CSS custom
/// properties were reachable from any rule in the original.
class Tokens extends InheritedWidget {
  const Tokens({
    super.key,
    this.pal = Pal.bridgeLight,
    this.hero = Hero_.white,
    required super.child,
  });

  final Pal pal;
  final Hero_ hero;

  static Tokens of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<Tokens>();
    assert(t != null, 'No Tokens ancestor. Wrap the app in a Tokens widget.');
    return t!;
  }

  @override
  bool updateShouldNotify(Tokens old) => pal != old.pal || hero != old.hero;
}

/// `Ctx.pal(context)` reads shorter than the InheritedWidget call at each use.
extension TokenLookup on BuildContext {
  Pal get pal => Tokens.of(this).pal;
  Hero_ get hero => Tokens.of(this).hero;
}

/// The shell caps at 430px and centres on wide screens, matching the web build.
const double kShellMaxWidth = 430;

/// Type ramp. The original uses arbitrary Tailwind sizes (text-[13.5px]); these
/// are the ones that actually appear, named by role rather than by pixel.
class T {
  T._();
  static const String family = 'Cairo';

  static const TextStyle bigNum =
      TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.1);
  static const TextStyle title =
      TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.25);
  static const TextStyle section =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle body = TextStyle(fontSize: 14, height: 1.45);
  static const TextStyle rowName =
      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.25);
  static const TextStyle rowSub = TextStyle(fontSize: 12, height: 1.35);
  static const TextStyle chip =
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.2);
  static const TextStyle label = TextStyle(fontSize: 12, height: 1.3);
  static const TextStyle micro = TextStyle(fontSize: 10.5, height: 1.2);
  static const TextStyle tab =
      TextStyle(fontSize: 10, fontWeight: FontWeight.w500, height: 1.2);
}
