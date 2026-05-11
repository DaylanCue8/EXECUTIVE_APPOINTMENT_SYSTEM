plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Only this one line
}

android {
    namespace = "executivesystem.com"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // --- ADD THESE THREE LINES TO FIX THE ERROR ---
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "executivesystem.com"
        minSdk = flutter.minSdkVersion // Firebase and notifications work best with at least 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // Helps with large libraries like Firebase
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// --- ADD THIS BLOCK AT THE VERY BOTTOM ---
dependencies {
    // This is the specific library that fixes the build failure
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:34.12.0"))
    implementation("com.google.firebase:firebase-analytics")
}
