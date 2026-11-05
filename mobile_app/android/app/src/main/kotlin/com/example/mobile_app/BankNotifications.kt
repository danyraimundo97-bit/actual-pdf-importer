package com.example.mobile_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Bank notifications waiting to become transactions. Kept dumb on purpose:
 * the text is read and parsed in Dart (where it's tested), and this keeps it
 * only until then, in a private file that device backups leave out. Nothing
 * here logs a notification's text.
 */
object BankNotifications {
    const val EXTRA_OPEN_ID = "bank_notification_id"
    private const val CHANNEL_ID = "bank_notifications"
    private const val MAX_WAITING = 100
    private const val REPOST_WINDOW_MS = 2 * 60 * 1000L

    private fun settings(context: Context) = context.getSharedPreferences("bank_notifications", Context.MODE_PRIVATE)

    /** The apps the user chose in Settings › Bank notifications. Nothing until then. */
    fun trackedApps(context: Context): Set<String> =
        settings(context).getStringSet("tracked", emptySet()) ?: emptySet()

    fun setTrackedApps(context: Context, packages: List<String>) {
        settings(context).edit().putStringSet("tracked", packages.toSet()).apply()
    }

    /** Apps with an icon in the launcher, for choosing from. */
    fun installedApps(context: Context): List<Map<String, String>> {
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val pm = context.packageManager
        return pm.queryIntentActivities(launcher, 0)
            .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .distinctBy { it.first }
            .filter { it.first != context.packageName }
            .sortedBy { it.second.lowercase() }
            .map { mapOf("package" to it.first, "label" to it.second) }
    }

    fun appLabel(context: Context, packageName: String): String = try {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
    } catch (_: Exception) {
        packageName
    }

    /** Which bank's rules read this app's text; "other" has only the general ones. */
    fun bankOf(packageName: String): String {
        val name = packageName.lowercase()
        return when {
            name.contains("moey") -> "moey"
            name.contains("activobank") -> "activobank"
            name.contains("mbway") -> "mbway"
            else -> "other"
        }
    }

    private fun file(context: Context) = File(context.noBackupFilesDir, "bank_notifications.json")

    @Synchronized
    private fun read(context: Context): MutableList<JSONObject> {
        val f = file(context)
        if (!f.exists()) return mutableListOf()
        return try {
            val array = JSONArray(f.readText())
            MutableList(array.length()) { array.getJSONObject(it) }
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    @Synchronized
    private fun write(context: Context, items: List<JSONObject>) {
        val tmp = File(context.noBackupFilesDir, "bank_notifications.json.tmp")
        tmp.writeText(JSONArray(items).toString())
        tmp.renameTo(file(context))
    }

    @Synchronized
    fun add(context: Context, packageName: String, bank: String, appName: String, title: String, text: String, postedAt: Long) {
        val items = read(context)
        // Banks repost and update the same notification.
        val again = items.any {
            it.getString("bank") == bank && it.getString("title") == title && it.getString("text") == text &&
                kotlin.math.abs(it.getLong("postedAt") - postedAt) < REPOST_WINDOW_MS
        }
        if (again) return
        val id = UUID.randomUUID().toString()
        items.add(
            JSONObject()
                .put("id", id)
                .put("package", packageName)
                .put("bank", bank)
                .put("appName", appName)
                .put("title", title)
                .put("text", text)
                .put("postedAt", postedAt),
        )
        write(context, items.takeLast(MAX_WAITING))
        notify(context, id, appName)
    }

    @Synchronized
    fun list(context: Context): List<Map<String, Any>> = read(context).map {
        mapOf(
            "id" to it.getString("id"),
            "package" to it.optString("package", ""),
            "bank" to it.getString("bank"),
            "appName" to it.optString("appName", it.getString("bank")),
            "title" to it.getString("title"),
            "text" to it.getString("text"),
            "postedAt" to it.getLong("postedAt"),
        )
    }

    @Synchronized
    fun remove(context: Context, id: String) {
        write(context, read(context).filter { it.getString("id") != id })
        context.getSystemService(NotificationManager::class.java)?.cancel(id.hashCode())
    }

    private fun notify(context: Context, id: String, appName: String) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Bank transactions", NotificationManager.IMPORTANCE_DEFAULT),
            )
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val open = Intent(context, MainActivity::class.java)
            .putExtra(EXTRA_OPEN_ID, id)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(
            context,
            id.hashCode(),
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        manager.notify(
            id.hashCode(),
            builder
                .setSmallIcon(R.mipmap.ic_launcher)
                // Our own words, never the bank's: its text can name an account.
                .setContentTitle("New transaction")
                .setContentText("$appName: tap to add it.")
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setContentIntent(tap)
                .setAutoCancel(true)
                .build(),
        )
    }
}
