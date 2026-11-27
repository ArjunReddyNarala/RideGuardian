plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStoreFile = providers.gradleProperty("RELEASE_STORE_FILE").orNull
    ?: System.getenv("RELEASE_STORE_FILE")
val releaseStorePassword = providers.gradleProperty("RELEASE_STORE_PASSWORD").orNull
    ?: System.getenv("RELEASE_STORE_PASSWORD")
val releaseKeyAlias = providers.gradleProperty("RELEASE_KEY_ALIAS").orNull
    ?: System.getenv("RELEASE_KEY_ALIAS")
val releaseKeyPassword = providers.gradleProperty("RELEASE_KEY_PASSWORD").orNull
    ?: System.getenv("RELEASE_KEY_PASSWORD")
val mapsApiKey = providers.gradleProperty("MAPS_API_KEY").orNull
    ?: System.getenv("MAPS_API_KEY")

android {
    namespace = "com.arjunreddynarala.rideguardian"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.arjunreddynarala.rideguardian"
        minSdk = 23
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey ?: ""
    }
    if (releaseStoreFile != null && releaseStorePassword != null &&
        releaseKeyAlias != null && releaseKeyPassword != null
    ) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
        buildTypes {
            release {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

tasks.configureEach {
    if (name == "bundleRelease" || name == "assembleRelease") {
        doFirst {
            check(!mapsApiKey.isNullOrBlank()) {
                "Set MAPS_API_KEY in ~/.gradle/gradle.properties or the environment before building a release."
            }
            check(releaseStoreFile != null && releaseStorePassword != null &&
                releaseKeyAlias != null && releaseKeyPassword != null
            ) {
                "Configure RELEASE_STORE_FILE, RELEASE_STORE_PASSWORD, RELEASE_KEY_ALIAS, and RELEASE_KEY_PASSWORD before building a release. See android/RELEASE.md."
            }
            check(file(releaseStoreFile!!).isFile) {
                "RELEASE_STORE_FILE does not point to a readable upload keystore."
            }
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
