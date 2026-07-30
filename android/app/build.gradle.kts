import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mycompany.move_base"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mycompany.move_base"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (System.getenv("CM_KEYSTORE_PATH") != null) {
                // Codemagic automatic signing
                storeFile = file(System.getenv("CM_KEYSTORE_PATH")!!)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")!!
                keyAlias = System.getenv("CM_KEY_ALIAS")!!
                keyPassword = System.getenv("CM_KEY_PASSWORD")!!
            } else {
                // Local development
                val keystoreFile = rootProject.file("key.properties")
                if (keystoreFile.exists()) {
                    val props = Properties()
                    props.load(keystoreFile.inputStream())
                    keyAlias = props["keyAlias"] as String
                    keyPassword = props["keyPassword"] as String
                    storeFile = file(props["storeFile"] as String)
                    storePassword = props["storePassword"] as String
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
