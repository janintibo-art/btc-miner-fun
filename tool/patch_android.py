"""Prepare le projet Android genere par `flutter create`.

Trois choses que Flutter ne fait pas tout seul :
  1. la permission INTERNET (absente des builds release) ;
  2. le nom affiche de l'application ;
  3. un service de premier plan en Kotlin, pour que le minage continue
     quand l'ecran s'eteint au lieu d'etre suspendu par Android.
"""
import pathlib
import sys

APP = pathlib.Path("android/app/src/main")
MANIFEST = APP / "AndroidManifest.xml"

if not MANIFEST.exists():
    sys.exit("Manifeste introuvable : lance d'abord flutter create.")

# --------------------------------------------------------------------------
# 1. Trouver le dossier Kotlin et le nom de package
# --------------------------------------------------------------------------
candidates = list(APP.glob("kotlin/**/MainActivity.kt"))
if not candidates:
    sys.exit("MainActivity.kt introuvable.")
main_activity = candidates[0]
kotlin_dir = main_activity.parent
package = ".".join(kotlin_dir.relative_to(APP / "kotlin").parts)
print("Package Android :", package)

# --------------------------------------------------------------------------
# 2. Le service de premier plan
# --------------------------------------------------------------------------
SERVICE_KT = """package __PACKAGE__

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Service de premier plan : tant qu'il tourne, Android garde le processus en
 * vie et le processeur reveille, meme ecran eteint. La notification permanente
 * est obligatoire, et c'est honnete : l'utilisateur voit que l'appareil calcule.
 */
class MiningService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title") ?: "Minage en cours"
        val text = intent?.getStringExtra("text") ?: ""

        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification(title, text))
        acquireWakeLock()
        return START_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // L'utilisateur a balaye l'application : on arrete tout proprement.
        releaseWakeLock()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun acquireWakeLock() {
        if (wakeLock != null) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "BTCMinerFun::mining")
        lock.setReferenceCounted(false)
        lock.acquire()
        wakeLock = lock
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (e: Exception) {
            // Deja relache : rien a faire.
        }
        wakeLock = null
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Minage",
            NotificationManager.IMPORTANCE_LOW
        )
        channel.description = "Affiche l'activite du mineur"
        channel.setShowBadge(false)
        channel.enableVibration(false)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, text: String): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        var pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingFlags = pendingFlags or PendingIntent.FLAG_IMMUTABLE
        }
        val pending = PendingIntent.getActivity(this, 0, launch, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pending)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "mining"
        const val NOTIFICATION_ID = 4711
    }
}
"""

(kotlin_dir / "MiningService.kt").write_text(
    SERVICE_KT.replace("__PACKAGE__", package), encoding="utf-8"
)
print("MiningService.kt ecrit.")

# --------------------------------------------------------------------------
# 3. MainActivity : le pont entre Dart et le service
# --------------------------------------------------------------------------
MAIN_KT = """package __PACKAGE__

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "btc_miner_fun/service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start", "update" -> {
                        ensureNotificationPermission()
                        val intent = Intent(this, MiningService::class.java)
                        intent.putExtra("title", call.argument<String>("title") ?: "Minage")
                        intent.putExtra("text", call.argument<String>("text") ?: "")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stop" -> {
                        stopService(Intent(this, MiningService::class.java))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < 33) return
        val granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }
}
"""

main_activity.write_text(MAIN_KT.replace("__PACKAGE__", package), encoding="utf-8")
print("MainActivity.kt reecrit avec le pont MethodChannel.")

# --------------------------------------------------------------------------
# 4. Le manifeste
# --------------------------------------------------------------------------
text = MANIFEST.read_text(encoding="utf-8")

permissions = [
    "android.permission.INTERNET",
    "android.permission.WAKE_LOCK",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
    "android.permission.POST_NOTIFICATIONS",
]
missing = "".join(
    '    <uses-permission android:name="{0}"/>\n'.format(p)
    for p in permissions
    if p not in text
)
if missing:
    text = text.replace("<application", missing + "    <application", 1)

if "MiningService" not in text:
    service = (
        '        <service\n'
        '            android:name=".MiningService"\n'
        '            android:exported="false"\n'
        '            android:stopWithTask="true"\n'
        '            android:foregroundServiceType="dataSync"/>\n'
        '    </application>'
    )
    text = text.replace("    </application>", service, 1)

text = text.replace('android:label="btc_miner_fun"', 'android:label="BTC Miner Fun"')

MANIFEST.write_text(text, encoding="utf-8")
print("Manifeste mis a jour.")
