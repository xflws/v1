# ── Flutter embedding ───────────────────────────────────────────────────
#
# Plugins are registered by reflection from generated code, so R8 cannot see
# the references and strips the classes. That produces exactly the symptom
# here: the app installs, launches, and dies immediately with a
# ClassNotFoundException or a MissingPluginException.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# ── Plugins in this app ─────────────────────────────────────────────────
#
# All of these resolve platform services or entry points reflectively.
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.tundralabs.fluttertts.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.multidex.** { *; }

# Kotlin metadata and coroutines, used reflectively by several plugins.
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ── Play Store deferred components ──────────────────────────────────────
#
# Flutter's embedding references these, but they only ship in an app bundle,
# never in an APK. The code paths are unreachable here, so silencing R8 is
# correct rather than a workaround.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# ── Keep annotations and signatures ─────────────────────────────────────
#
# Stripping these breaks reflection and generics at runtime in ways that only
# appear in a release build.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable
