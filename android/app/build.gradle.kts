plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

// Load keystore properties from android/key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val storeFilePropConfigured = if (keystorePropertiesFile.exists()) keystoreProperties["storeFile"] as String? else null
val storeFileCandidate = storeFilePropConfigured?.let { runCatching { rootProject.file(it) }.getOrNull() }
val hasKeystore = storeFileCandidate?.exists() == true

android {
    namespace = "com.lexiflow.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        // ✅ Java 17 desteği + desugaring aktif
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // ✅ Kotlin derleyicisi de Java 17’ye göre ayarlandı
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

   defaultConfig {
    applicationId = "com.lexiflow.app"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
    }


    signingConfigs {
        if (hasKeystore) {
            create("release") {
                val keyAliasProp = keystoreProperties["keyAlias"] as String?
                val keyPasswordProp = keystoreProperties["keyPassword"] as String?
                val storePasswordProp = keystoreProperties["storePassword"] as String?

                if (keyAliasProp != null) keyAlias = keyAliasProp
                if (keyPasswordProp != null) keyPassword = keyPasswordProp
                storeFile = storeFileCandidate
                if (storePasswordProp != null) storePassword = storePasswordProp
            }
        }
    }

    buildTypes {
        release {
            if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
      coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
      implementation("androidx.appcompat:appcompat:1.4.0")
      implementation("androidx.activity:activity-ktx:1.9.0")


}
