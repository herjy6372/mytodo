import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 키 정보 로드 (없으면 디버그 키로 폴백)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()
        && keystoreProperties["storeFile"] != null

android {
    namespace = "com.terablack.mytodo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 가 java.time API 사용 → core library desugaring 필요
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // ⚠️ 플레이 스토어는 com.example.* 패키지명을 거부합니다.
        // 실제 출시 전에 본인 소유 도메인 기반(예: com.terablack.mytodo)으로
        // 변경한 뒤 `flutterfire configure` 를 다시 실행하셔야 합니다.
        applicationId = "com.terablack.mytodo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                // key.properties 가 없으면 디버그 키로 폴백 (개발 편의)
                signingConfigs.getByName("debug")
            }
            // R8: 사용하지 않는 코드·리소스 제거 + Java/Kotlin 코드 난독화
            // (Dart 코드는 `flutter build appbundle --obfuscate` 로 별도 난독화)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // core library desugaring (flutter_local_notifications 요구)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Android 15 미만에서도 전체 화면(edge-to-edge) 표시 (WindowCompat)
    implementation("androidx.core:core-ktx:1.13.1")
}

