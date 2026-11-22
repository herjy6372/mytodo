package com.terablack.mytodo

import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockIfAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockIfAlarm(intent)
    }

    /** 알람 알림(전체 화면 알림)으로 열린 경우에만 잠금 화면 위에 표시하고 화면을 켬. */
    private fun showOverLockIfAlarm(intent: Intent?) {
        if (intent?.action != "SELECT_NOTIFICATION") return
        val payload = intent.getStringExtra("payload") ?: return
        if (payload.startsWith("alarm:") || payload.startsWith("todoalarm:") ||
            payload.startsWith("snooze:")
        ) setShowOverLock(true)
    }

    private fun setShowOverLock(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mytodo/alarm_sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> { startSound(); result.success(null) }
                    "stop" -> { stopSound(); setShowOverLock(false); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    /** 알람 볼륨으로 알람음을 반복 재생 (멈출 때까지). */
    private fun startSound() {
        stopSound()
        player = MediaPlayer.create(
            this,
            R.raw.alarm,
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
            0,
        )?.apply {
            isLooping = true
            start()
        }
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
        vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 800, 600), 0))
    }

    private fun stopSound() {
        player?.run { if (isPlaying) stop(); release() }
        player = null
        vibrator?.cancel()
        vibrator = null
    }

    override fun onDestroy() {
        stopSound()
        super.onDestroy()
    }
}
