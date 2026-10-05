plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pharmacy.pharmacy_pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pharmacy.pharmacy_pos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Stable CI signing key. CI restores the ANDROID_KEYSTORE_B64 secret to
    // this exact path before the build; naming the file explicitly is what
    // forces AGP to use it (a merely placed ~/.android/debug.keystore is
    // silently ignored by newer AGP, which then generates a fresh key per
    // build and breaks in-place updates — 2026-10-05).
    val stableKeystoreFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
    signingConfigs {
        create("ciStable") {
            storeFile = stableKeystoreFile
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            // CI restores a stable keystore to ~/.android/debug.keystore from
            // the ANDROID_KEYSTORE_B64 secret (see .github/workflows/ci.yml).
            // The config must name the file explicitly: newer AGP silently
            // ignores a merely placed ~/.android/debug.keystore and generates
            // a fresh key per build, which makes every APK uninstall the
            // previous one (2026-10-05). Falls back to the default debug
            // signing when the file is absent (local dev machines).
            signingConfig = if (stableKeystoreFile.exists())
                signingConfigs.getByName("ciStable")
            else
                signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
