package com.example.mobile_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Sees every notification, as Android's listener always does, and looks inside
 * only those from the apps the user chose: any other is dropped on its package name.
 */
class BankNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in BankNotifications.trackedApps(applicationContext)) return
        val notification = sbn.notification ?: return
        if (sbn.isOngoing || notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: extras.getCharSequence(Notification.EXTRA_TEXT))
            ?.toString()
            .orEmpty()
        if (title.isBlank() && text.isBlank()) return
        BankNotifications.add(
            applicationContext,
            sbn.packageName,
            BankNotifications.bankOf(sbn.packageName),
            BankNotifications.appLabel(applicationContext, sbn.packageName),
            title,
            text,
            sbn.postTime,
        )
    }
}
