// The hero card style, held as app state so changing it repaints.
//
// The palettes were always in tokens.dart; what was missing is that the hero
// was passed as a fixed value at the app root, so the picker had nothing to
// change.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tokens.dart';

class ThemeController extends ChangeNotifier {
  static const String _key = 'xflws.hero';

  String _style = 'white';

  /// white | cream | navy
  String get style => _style;

  Hero_ get hero => switch (_style) {
        'cream' => Hero_.cream,
        'navy' => Hero_.navy,
        _ => Hero_.white,
      };

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key);
      if (v != null && v != _style) {
        _style = v;
        notifyListeners();
      }
    } catch (_) {
      // The default stands.
    }
  }

  Future<void> select(String style) async {
    if (style == _style) return;
    _style = style;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, style);
    } catch (_) {}
  }
}
