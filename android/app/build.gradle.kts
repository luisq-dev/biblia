import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (releaseRequested) {
    require(signingPropertiesFile.exists()) {
        "Falta android/key.properties. Ejecuta python3 scripts/configure_signing.py antes de compilar una versión pública."
    }
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach { key ->
        require(!signingProperties.getProperty(key).isNullOrBlank()) { "Falta la propiedad de firma: $key" }
    }
}

android {
    namespace = "com.example.biblia"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Conservar el ID permite mantener los datos al actualizar con la misma firma.
        applicationId = "com.example.biblia"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // La versión se obtiene de pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (signingPropertiesFile.exists()) {
                storeFile = signingProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
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
