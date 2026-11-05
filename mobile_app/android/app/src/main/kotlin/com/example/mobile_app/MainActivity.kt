package com.example.mobile_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var openedId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        openedId = intent?.getStringExtra(BankNotifications.EXTRA_OPEN_ID)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(BankNotifications.EXTRA_OPEN_ID)?.let {
            channel?.invokeMethod("opened", it)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bank_notifications").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "list" -> result.success(BankNotifications.list(this@MainActivity))
                    "remove" -> {
                        BankNotifications.remove(this@MainActivity, call.arguments as String)
                        result.success(null)
                    }
                    "takeOpened" -> {
                        result.success(openedId)
                        openedId = null
                    }
                    "installedApps" -> result.success(BankNotifications.installedApps(this@MainActivity))
                    "trackedApps" -> result.success(BankNotifications.trackedApps(this@MainActivity).toList())
                    "setTrackedApps" -> {
                        @Suppress("UNCHECKED_CAST")
                        BankNotifications.setTrackedApps(this@MainActivity, call.arguments as List<String>)
                        result.success(null)
                    }
                    "isEnabled" -> result.success(listenerEnabled())
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "requestPost" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun listenerEnabled(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return enabled.split(":").any { it.startsWith("$packageName/") }
    }
}
