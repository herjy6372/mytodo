import Flutter
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: 백그라운드/종료 상태에서 예약 알림이 도착했을 때
    // Flutter 엔진이 다시 등록될 수 있도록 콜백을 설정합니다.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    installWidgetAlarmSound()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 위젯 타이머 알림이 알람음을 쓸 수 있도록 App Group 의 Library/Sounds 에 복사합니다.
  private func installWidgetAlarmSound() {
    guard
      let group = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.example.mytodo"),
      let source = Bundle.main.url(
        forResource: "alarm", withExtension: "wav",
        subdirectory: "Frameworks/App.framework/flutter_assets/assets/sounds")
    else { return }
    let dir = group.appendingPathComponent("Library/Sounds", isDirectory: true)
    let target = dir.appendingPathComponent("alarm.wav")
    if FileManager.default.fileExists(atPath: target.path) { return }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try? FileManager.default.copyItem(at: source, to: target)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
