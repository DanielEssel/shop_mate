import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (never committed; see
// .gitignore): storeFile, storePassword, keyAlias, keyPassword. Debug builds
// do not need it. A release build without a complete configuration, or with
// the debug keystore, fails instead of being signed with the debug key.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.isFile) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val requiredSigningProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

fun signingProperty(name: String): String? =
    keystoreProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

// "~/" is expanded; properties files do not expand $HOME.
val releaseStoreFile: File? = signingProperty("storeFile")?.let { path ->
    file(if (path.startsWith("~/")) System.getProperty("user.home") + path.substring(1) else path)
}

android {
    namespace = "com.example.shopmate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kodanx.shopmate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = releaseStoreFile
            storePassword = signingProperty("storePassword")
            keyAlias = signingProperty("keyAlias")
            keyPassword = signingProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            // The ShopMate release key only; never the debug key.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Checked only when a release task is about to run, so debug builds work
// without key.properties. Names what is wrong, never any value.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { task ->
        task.project == project && task.name.contains("Release")
    }
    if (!buildsRelease) return@whenReady

    if (!keystorePropertiesFile.isFile) {
        throw GradleException(
            "Release signing is not configured: ${keystorePropertiesFile.path} is missing. " +
                "Create it with $requiredSigningProperties.",
        )
    }
    val missing = requiredSigningProperties.filter { signingProperty(it) == null }
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Release signing is incomplete: ${keystorePropertiesFile.path} has no value for $missing.",
        )
    }
    val storeFile = releaseStoreFile!!
    if (!storeFile.isFile) {
        throw GradleException("Release signing: the keystore file does not exist: ${storeFile.path}")
    }
    if (storeFile.name == "debug.keystore" || signingProperty("keyAlias") == "androiddebugkey") {
        throw GradleException("Release signing must use the ShopMate release key, not the debug key.")
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
