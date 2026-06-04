plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.isai.music"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.isai.music"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystoreFile = file("isai-release.keystore")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: "isaismusicplayer"
                keyAlias = System.getenv("ANDROID_ALIAS") ?: "isaimusic"
                keyPassword = System.getenv("ANDROID_KEYPASS") ?: "isaismusicplayer"
            } else {
                // Fallback to debug keys if the keystore file is absent
                storeFile = signingConfigs.getByName("debug").storeFile
                storePassword = signingConfigs.getByName("debug").storePassword
                keyAlias = signingConfigs.getByName("debug").keyAlias
                keyPassword = signingConfigs.getByName("debug").keyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    applicationVariants.all {
        outputs.forEach { output ->
            val outputImpl = output as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            var abiFilter = outputImpl.filters.firstOrNull { it.filterType == "ABI" }?.identifier ?: ""
            if (abiFilter == "arm64-v8a") {
                abiFilter = "v8a"
            } else if (abiFilter == "armeabi-v7a") {
                abiFilter = "v7a"
            }
            val abiSuffix = if (abiFilter.isNotEmpty()) "-$abiFilter" else ""
            outputImpl.outputFileName = "isai-${versionName}${abiSuffix}-${name}.apk"
        }
    }
}

flutter {
    source = "../.."
}
