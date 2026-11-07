import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProps = rootProject.file("key.properties")

android {
    namespace = "com.ssokmemo.biseo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ssokmemo.biseo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyProps.exists()) {
            create("release") {
                val p = Properties().apply { keyProps.inputStream().use { load(it) } }
                keyAlias = p.getProperty("keyAlias")
                keyPassword = p.getProperty("keyPassword")
                storeFile = file(p.getProperty("storeFile"))
                storePassword = p.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProps.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("WARNING: android/key.properties not found; release APK is debug-signed.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

// 키 없이 release를 서명하려면 명시적으로 허용해야 한다(디버그 빌드는 영향 없음).
gradle.taskGraph.whenReady {
    if (!keyProps.exists() && !project.hasProperty("allowDebugSign") &&
        allTasks.any { it.name.contains("Release") }
    ) {
        throw GradleException(
            "android/key.properties not found: refusing to debug-sign a release APK. " +
                "(dev only: flutter build apk --release --android-project-arg=allowDebugSign=true)"
        )
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

// 실제 폰은 모두 ARM: release에서 x86 라이브러리를 빼 배포 APK를 줄인다.
// 에뮬레이터용 release는 --android-project-arg=withX86=true 로 빌드한다.
androidComponents {
    onVariants(selector().withBuildType("release")) { v ->
        if (!project.hasProperty("withX86")) {
            v.packaging.jniLibs.excludes.addAll(listOf("lib/x86/**", "lib/x86_64/**"))
        }
    }
}
