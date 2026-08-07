plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // docs/07-musteriapp.md §6 — Google Play paket adı.
    namespace = "com.veykemtu.catering"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications, minSdk altındaki cihazlarda java.time
        // gibi API'leri kullanabilmek için core library desugaring ister.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.veykemtu.catering"
        minSdk = flutter.minSdkVersion
        // Play'in güncel zorunluluğu Flutter araç zincirinden gelir.
        targetSdk = flutter.targetSdkVersion
        // versionName pubspec.yaml'daki `version:` alanından gelir ve
        // X-App-Version başlığıyla aynıdır.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // İmzalama anahtarı CI gizli değişkenlerindedir ve repoda yoktur
            // (AGENTS.md §2.2, docs/07-musteriapp.md §6). I-06 tamamlanana
            // kadar `flutter build` debug anahtarıyla imzalar.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    // Core library desugaring çalışma zamanı kütüphanesi (compileOptions'daki
    // isCoreLibraryDesugaringEnabled ile birlikte gerekir).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
