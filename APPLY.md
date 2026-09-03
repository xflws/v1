# XFLWS — final hotfix. Calls simulated, APK builds.

Unzip at the project root, overwriting. Then:

    flutter clean
    flutter pub get
    flutter build apk --release --split-per-abi --dart-define=XFLWS_API=https://xerp.xflws.com

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

## What changed

`flutter_webrtc` is commented out of `pubspec.yaml`. That plugin at version
0.12.12 declares compileSdk 31 and cannot be built against AGP 9 — every
Gradle workaround we tried failed on a different part of the same
incompatibility. It was one plugin blocking an entire app.

With it gone, the Gradle files go back to close to stock. No compileSdk
override, no reflection, no JVM-target forcing. The remaining plugins build
against a modern SDK on their own.

## What the call screen does now

Everything except the video stream is real and runs through your API:

- the whiteboard, synchronised both ways stroke by stroke
- chat
- presence, so each side sees when the other is connected
- the call lifecycle: start, ring, answer, end, with elapsed time

Simulated: the audio and video streams. The screen shows the other party's
initial and says plainly that video is simulated while the whiteboard and chat
are live. A blank video panel would just look like a crash.

Mic and camera buttons still toggle, so the interaction is intact for a demo.

## Restoring real video later

Two changes, no server work:

1. Uncomment `flutter_webrtc` in `pubspec.yaml`
2. Restore `lib/screens/call.dart` from the full project archive

The backend is untouched by any of this. `call.signal`, `call.poll`,
`call.draw` and the rest are plain HTTP and were never tied to the plugin — the
signalling that a real WebRTC connection needs is already there and working.
Watch pub.dev for a flutter_webrtc release that supports AGP 9, then flip it
back.

Web is unaffected either way: browsers have WebRTC built in.

## R8 and the Play Store classes

Flutter's embedding references Google Play deferred-component classes that only
exist in an app bundle, never in an APK. R8 sees the references, cannot resolve
them, and stops. `-dontwarn com.google.android.play.core.**` is the correct
answer rather than a workaround: those code paths are genuinely unreachable in
an APK build.

## Still in place

Icon tree-shaking, ProGuard keep rules for both speech plugins, multidex, core
library desugaring, and debug signing so the release build needs no keystore.
Replace the signing config before publishing.
