import java.util.Properties

// ── Load key.properties ────────────────────────────────────────────────────
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.serbisyoalisto.serbisyo_alisto_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.serbisyoalisto.serbisyo_alisto_1"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ── Signing configs ────────────────────────────────────────────────────
    signingConfigs {
        create("customDebug") {
            keyAlias     = keyProperties["keyAlias"]     as String? ?: "androiddebugkey"
            keyPassword  = keyProperties["keyPassword"]  as String? ?: "android"
            storeFile    = file(keyProperties["storeFile"] as String? ?: "${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = keyProperties["storePassword"] as String? ?: "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("customDebug")
        }
        release {
            // Use same custom signing for release until you have a release keystore
            signingConfig = signingConfigs.getByName("customDebug")
        }
    }
}

flutter {
    source = "../.."
} 