# XFLWS — Flutter app

A port of the XFLWS PWA, backed by the PHP API in the separate `xflws-api`
package. The two are matched; upload both.

## Build

    flutter clean
    flutter pub get
    flutter run -d chrome --dart-define=XFLWS_API=https://xerp.xflws.com

Android release APK:

    flutter build apk --release --split-per-abi --dart-define=XFLWS_API=https://xerp.xflws.com

Output at `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` — the
arm64 one is for any modern phone.

iOS needs a Mac. `flutter create . --platforms=ios`, open
`ios/Runner.xcworkspace`, set a signing team, deployment target 13+.

## Sign in

Run `php seed.php` on the backend first, or press **Seed demo data** in the
console under Overview. Without it you sign in to an empty portfolio.

Customers, password `demo1234`:
`ahmed.hassan@gmail.com` (9 positions), `mona.k@gmail.com`,
`y.adel@outlook.com`, `omar.tarek@gmail.com`

Adviser: `hazem@xflws.com` / `xflws2026` — gets the adviser view with assigned
clients and a call button, not the customer tabs.

## What is exact, and how

The parts that had to be faithful were extracted from the original rather than
eyeballed:

- **Cairo 400/500/600/700** from the base64 `@font-face` blocks, woff2 → TTF.
  400 and 600 are the latin and Arabic subsets merged, 648 glyphs each.
- **Phosphor regular and fill**, 119 glyphs. `lib/core/ph.dart` is generated
  from the CSS `content:"\eXXX"` rules, so every icon sits at the codepoint the
  web build declares.
- **Colours** transcribe the `PAL` and `HERO` objects verbatim.
- **The Cairo skyline** behind the hero, and the brand wordmark, straight from
  the original assets.

## Where this build deliberately differs from the PWA

Each of these is a place the prototype did something that should not ship:

- **Order fees** come from `?r=orders.quote`, never computed locally. A ticket
  doing its own arithmetic and a statement using the engine's will eventually
  disagree, and the customer is who finds out.
- **Balances** show `available`, never the ledger total, and name held funds
  when there are any. Showing held money as spendable is how someone places two
  orders they cannot both afford.
- **Card PAN, CVV and PIN** never leave the server.
- **The card details gate** says plainly that nothing was verified. The PWA
  accepted any tap; its own README calls that unacceptable before launch.
- **Voice never completes a money movement.** Buy, sell and transfer open the
  screen pre-filled and you confirm there. "Sell 100" and "sell 110" sound
  alike.
- **KYC capture** is not connected and says so, rather than letting an
  unverified account through onboarding.
- **The AI assistant** says it is not connected instead of returning canned
  text that reads like analysis of real money.

## Known limits

- **Video calling is simulated.** flutter_webrtc 0.12.12 declares compileSdk 31
  and cannot build against AGP 9. The whiteboard, chat, presence and call
  lifecycle are all live through the API; only the media stream is stubbed, and
  the screen says so. Restoring it: uncomment the dependency in `pubspec.yaml`
  and restore `lib/screens/call.dart` from an archive that has the WebRTC
  version. No server change — the signalling routes are plain HTTP.
- **Minification is off** for release builds. R8 strips Flutter's reflectively
  registered plugins. Turn `isMinifyEnabled` back on in
  `android/app/build.gradle.kts` once you can test a minified release on a real
  device.
- **Debug signing** on release, so no keystore is needed. Replace it before
  publishing: an APK signed with the debug key cannot be updated by a properly
  signed one later.
- No Arabic strings. The layout mirrors correctly when they exist.

## Layout

    lib/core/       palette, generated icons, currency, voice parser, theme
    lib/data/       API client, models, per-platform HTTP client
    lib/widgets/    charts, treemap, tab bar, shared primitives
    lib/screens/    one file per screen
    android/        manifest, Gradle, launcher icons
    assets/         fonts, brand marks, skyline
