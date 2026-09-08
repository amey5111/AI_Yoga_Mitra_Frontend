import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yogamitra.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.yogamitra.app"
        minSdk = maxOf(24, flutter.minSdkVersion) // Vosk plugin needs 24+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: ""
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: ""
            storeFile = file("upload-keystore.jks")
            storePassword = keystoreProperties.getProperty("storePassword") ?: ""
        }
    }

    buildTypes {
        getByName("debug") {
            // A debug APK with every architecture in it is ~430 MB, and Android
            // re-verifies all of it on each install. Physical test devices are
            // arm64, so ship only that while developing — it roughly halves the
            // install and takes minutes off the edit/run loop.
            //
            // Testing on a Windows/Intel emulator instead? Add "x86_64" here.
            // Release builds and the Play Store bundle are untouched.
            ndk {
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
        }

        getByName("release") {
            // Use the real upload keystore when configured (key.properties present);
            // otherwise fall back to debug signing so a shareable release APK still builds.
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = false      // keep Agora / video_player classes intact
            isShrinkResources = false
        }
    }

    bundle {
        language  { enableSplit = false }
        density   { enableSplit = false }
        abi       { enableSplit = true  }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}