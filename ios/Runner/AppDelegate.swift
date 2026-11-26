import AVFoundation
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
        forSecurityApplicationGroupIdentifier: "group.com.terablack.mytodo"),
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AlarmSound") {
      let channel = FlutterMethodChannel(
        name: "mytodo/alarm_sound", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "start": self?.startAlarmSound(); result(nil)
        case "stop": self?.stopAlarmSound(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  // MARK: - 알람 화면 소리

  private var alarmPlayer: AVAudioPlayer?

  /// 무음 스위치와 관계없이 알람음을 반복 재생합니다 (멈출 때까지).
  private func startAlarmSound() {
    stopAlarmSound()
    guard let url = Bundle.main.url(
      forResource: "alarm", withExtension: "wav",
      subdirectory: "Frameworks/App.framework/flutter_assets/assets/sounds")
    else { return }
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    try? AVAudioSession.sharedInstance().setActive(true)
    alarmPlayer = try? AVAudioPlayer(contentsOf: url)
    alarmPlayer?.numberOfLoops = -1
    alarmPlayer?.play()
  }

  private func stopAlarmSound() {
    alarmPlayer?.stop()
    alarmPlayer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
