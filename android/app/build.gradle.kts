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

// 릴리스 키 정보 로드.
// key.properties 가 없으면 릴리스 빌드는 실패합니다.
// (디버그 키 서명이 정말 필요하면 -PallowDebugSigning 을 명시적으로 전달)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()
        && keystoreProperties["storeFile"] != null
val allowDebugSigning = project.findProperty("allowDebugSigning")?.toString()?.lowercase() != "false"
        && project.hasProperty("allowDebugSigning")

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
            signingConfig = when {
                hasReleaseKey -> signingConfigs.getByName("release")
                // 명시적으로 요청한 경우에만 공개된 디버그 키로 서명 (로컬 테스트용, 스토어 업로드 불가)
                allowDebugSigning -> signingConfigs.getByName("debug")
                // 그 외에는 아래 taskGraph 검사에서 릴리스 빌드를 실패시킴
                else -> null
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

// 릴리스 키 없이 릴리스 빌드를 시도하면 조용히 디버그 키로 서명하지 않고 즉시 실패.
// (설정 단계가 아닌 태스크 그래프 단계에서 검사하므로 디버그 빌드·flutter run 은 영향 없음)
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { it.project == project && it.name.contains("Release") }
    if (buildsRelease && !hasReleaseKey && !allowDebugSigning) {
        throw GradleException(
            """
            |릴리스 서명 키가 없습니다: android/key.properties 파일이 없거나 storeFile 항목이 비어 있습니다.
            |
            |해결 방법 (둘 중 하나):
            |  1) android/key.properties.example 을 android/key.properties 로 복사한 뒤
            |     storePassword / keyPassword / keyAlias / storeFile 값을 채우세요.
            |     (docs/play_store_release_guide.md 의 3번 단계 참고)
            |  2) 스토어에 올리지 않는 로컬 테스트용이라면 디버그 키 서명을 명시적으로 허용하세요:
            |       flutter build apk --release --android-project-arg=allowDebugSigning=true
            |       또는 ./gradlew assembleRelease -PallowDebugSigning
            |     ⚠️ 디버그 키는 공개된 키이므로 이 빌드는 Play Store 에 업로드할 수 없습니다.
            """.trimMargin()
        )
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

