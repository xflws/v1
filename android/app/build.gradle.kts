import com.android.build.api.dsl.ApplicationExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("com.android.application")
    // Built-in Kotlin — the `kotlin-android` plugin is no longer needed
    // and causes build failures with modern Flutter.
    id("dev.flutter.flutter-gradle-plugin")
}

// AGP 9 removes the `android { }` accessor and `kotlinOptions { }` from the
// Kotlin DSL. Note that `android.newDsl=false` does not help here: the build
// script is compiled before that property is read, so the old syntax is a hard
// script-compilation error regardless. Configuring the extension by type is the
// form that works on AGP 8 and 9 alike.
extensions.configure<ApplicationExtension>("android") {
    namespace = "com.xflws.app"

    compileSdk = 36

    // Six plugins ask for this one. NDK releases are backward compatible.
    ndkVersion = "28.2.13676358"

    compileOptions {
        // 11, matching what the plugins were written for, rather than forcing
        // 17 and then fighting the mismatch.
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Lets newer Java APIs run on older devices.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.xflws.app"

        minSdk = flutter.minSdkVersion
        targetSdk = 34

        versionCode = 1
        versionName = "1.0.0"

        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            // Debug signing so the release build needs no keystore. Replace
            // before publishing: an APK signed with the debug key cannot be
            // updated by a properly signed one later.
            signingConfig = signingConfigs.getByName("debug")

            // Minification is off.
            //
            // R8 strips classes it cannot see referenced, and Flutter registers
            // plugins reflectively from generated code, so it cannot see most
            // of them. That is what makes a release APK install, launch and die
            // immediately while the debug build is fine.
            //
            // The keep rules in proguard-rules.pro are correct and are still
            // applied, but chasing one missing class at a time on a device with
            // no logs is a poor trade for roughly 3MB. Turn this back on once
            // the app is confirmed working, and test the release build on a
            // real device before shipping.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// Set on the compile tasks, since kotlinOptions no longer exists. Matched to
// the Java target above so the two agree.
//
// This only configures the task; it does not touch classpaths. An earlier
// attempt reassigned compatibility inside doFirst and wiped the Android SDK
// off the bootclasspath, which is what caused "package android does not exist".
tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

dependencies {
    add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
    add("implementation", "androidx.multidex:multidex:2.0.1")
}
