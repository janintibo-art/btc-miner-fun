"""Prepare le projet Android genere par ``flutter create``.

Le depot conserve volontairement seulement les sources Flutter. La CI regenere
le dossier Android puis ce script ajoute :
  * les permissions necessaires ;
  * un service de premier plan pour le calcul explicite lance par l'utilisateur ;
  * le pont MethodChannel entre Dart et Android.

Le service utilise ``specialUse`` plutot que ``dataSync`` : le minage n'est pas
une synchronisation de donnees et Android 15 limite les services dataSync a six
heures cumulees par 24 h. Le sous-type est documente dans le manifeste pour la
revue Play Console.
"""
from __future__ import annotations

import pathlib
import re
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
# 2. Service de premier plan
# --------------------------------------------------------------------------
SERVICE_KT = r'''package __PACKAGE__

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
 * Service de premier plan : il garde le processus et le CPU disponibles tant
 * que l'utilisateur a explicitement lance le minage. La notification permanente
 * rend l'activite visible et le wakelock est toujours relache a l'arret.
 */
class MiningService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Arret demande depuis la notification : on leve le drapeau que Dart
        // consulte chaque seconde, puis on s'arrete proprement.
        if (intent?.action == ACTION_STOP) {
            stopRequested = true
            releaseWakeLock()
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra("title") ?: "Minage en cours"
        val text = intent?.getStringExtra("text") ?: ""

        createChannel(this)
        startForeground(NOTIFICATION_ID, buildNotification(this, title, text))
        acquireWakeLock()

        // Si Android tue le processus, le moteur Dart disparait lui aussi. Il ne
        // faut donc surtout pas recreer seulement le service et son wakelock.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        releaseWakeLock()
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "BTCMinerFun::mining")
        lock.setReferenceCounted(false)
        lock.acquire()
        wakeLock = lock
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
            // Deja relache : rien a faire.
        }
        wakeLock = null
    }

    companion object {
        const val CHANNEL_ID = "mining"
        const val NOTIFICATION_ID = 4711
        const val ACTION_STOP = "btc_miner_fun.STOP"

        // Leve par le bouton "Arreter" de la notification, lu puis remis a
        // zero par Dart. Evite d'avoir a reveiller l'application depuis le
        // service : le processus est de toute facon vivant tant qu'il mine.
        @Volatile
        var stopRequested: Boolean = false

        fun updateNotification(context: Context, title: String, text: String) {
            createChannel(context)
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(context, title, text))
        }

        private fun createChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
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

        private fun buildNotification(context: Context, title: String, text: String): Notification {
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            var pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                pendingFlags = pendingFlags or PendingIntent.FLAG_IMMUTABLE
            }
            val pending = if (launch != null) {
                PendingIntent.getActivity(context, 0, launch, pendingFlags)
            } else {
                null
            }

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }

            val stopIntent = Intent(context, MiningService::class.java)
            stopIntent.action = ACTION_STOP
            val stopPending =
                PendingIntent.getService(context, 1, stopIntent, pendingFlags)

            builder
                .setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(context.applicationInfo.icon)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .addAction(android.R.drawable.ic_media_pause, "Arreter", stopPending)
            if (pending != null) builder.setContentIntent(pending)
            return builder.build()
        }
    }
}
'''

(kotlin_dir / "MiningService.kt").write_text(
    SERVICE_KT.replace("__PACKAGE__", package), encoding="utf-8"
)
print("MiningService.kt ecrit.")

# --------------------------------------------------------------------------
# 3. MainActivity : pont Dart <-> service
# --------------------------------------------------------------------------
MAIN_KT = r'''package __PACKAGE__

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
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
                    "start" -> {
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
                    "update" -> {
                        // Mettre a jour la notification ne redemarre pas le
                        // foreground service : important pour Android 12+.
                        MiningService.updateNotification(
                            this,
                            call.argument<String>("title") ?: "Minage",
                            call.argument<String>("text") ?: ""
                        )
                        result.success(true)
                    }
                    "stop" -> {
                        stopService(Intent(this, MiningService::class.java))
                        MiningService.stopRequested = false
                        result.success(true)
                    }
                    // Temperature de la batterie, en degres. C'est le seul
                    // capteur thermique lisible sans permission ; il suit de
                    // pres l'echauffement du processeur.
                    "temperature" -> {
                        val intent = registerReceiver(
                            null,
                            IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                        )
                        val tenths = intent?.getIntExtra(
                            BatteryManager.EXTRA_TEMPERATURE, -1
                        ) ?: -1
                        result.success(if (tenths < 0) -1.0 else tenths / 10.0)
                    }
                    // Drapeau leve par le bouton "Arreter" de la notification.
                    "consume_stop_request" -> {
                        val requested = MiningService.stopRequested
                        MiningService.stopRequested = false
                        result.success(requested)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "btc_miner_fun/security")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setProtected" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
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
'''

main_activity.write_text(MAIN_KT.replace("__PACKAGE__", package), encoding="utf-8")
print("MainActivity.kt reecrit avec le pont MethodChannel.")

# --------------------------------------------------------------------------
# 4. Manifeste
# --------------------------------------------------------------------------
text = MANIFEST.read_text(encoding="utf-8")

# Le coffre contient une phrase BIP39 chiffree. Les sauvegardes Android
# automatiques sont desactivees pour ne pas restaurer un blob chiffre sur un
# appareil dont la cle Keystore est differente.
if 'android:allowBackup=' not in text:
    text = text.replace(
        '<application',
        '<application\n        android:allowBackup="false"',
        1,
    )
else:
    text = re.sub(
        r'android:allowBackup="[^"]*"',
        'android:allowBackup="false"',
        text,
        count=1,
    )

# Migration si le script est relance sur un ancien dossier Android.
text = text.replace(
    "android.permission.FOREGROUND_SERVICE_DATA_SYNC",
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
)
text = text.replace('android:foregroundServiceType="dataSync"',
                    'android:foregroundServiceType="specialUse"')

permissions = [
    "android.permission.INTERNET",
    "android.permission.WAKE_LOCK",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
    "android.permission.POST_NOTIFICATIONS",
]
missing = "".join(
    '    <uses-permission android:name="{0}"/>\n'.format(permission)
    for permission in permissions
    if permission not in text
)
if missing:
    text = text.replace("<application", missing + "    <application", 1)

service_block = '''        <service
            android:name=".MiningService"
            android:exported="false"
            android:stopWithTask="true"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="User-initiated Bitcoin proof-of-work computation while a persistent notification is visible."/>
        </service>
'''

# Supprimer une declaration MiningService precedente pour rendre le script
# idempotent, sans consommer l'indentation/fermeture de <application>.
text = re.sub(
    r'\n[ \t]*<service\s+[^>]*android:name="\.MiningService"[\s\S]*?</service>[ \t]*\n?',
    '\n',
    text,
    count=1,
)
text = re.sub(
    r'\n[ \t]*<service\s+[^>]*android:name="\.MiningService"[^>]*/>[ \t]*\n?',
    '\n',
    text,
    count=1,
)
if "</application>" not in text:
    sys.exit("Balise </application> introuvable dans le manifeste.")
text = text.replace("</application>", service_block + "    </application>", 1)
text = text.replace('android:label="btc_miner_fun"', 'android:label="BTC Miner Fun"')

MANIFEST.write_text(text, encoding="utf-8")
print("Manifeste mis a jour (foreground service specialUse + backup desactive).")

# --------------------------------------------------------------------------
# 5. Versions du SDK Android.
#
#    flutter_secure_storage 11 se compile contre l'API 37 et refuse de se lier
#    a une application compilee contre une version anterieure. Flutter, lui,
#    propose encore 36 par defaut. Il faut donc remonter compileSdk, et
#    neutraliser l'avertissement du plugin Gradle qui considere 36 comme son
#    maximum recommande : c'est un avertissement, pas une incompatibilite.
# --------------------------------------------------------------------------
COMPILE_SDK = 37
MIN_SDK = 24

gradle_kts = pathlib.Path("android/app/build.gradle.kts")
gradle_groovy = pathlib.Path("android/app/build.gradle")

if gradle_kts.exists():
    gradle = gradle_kts.read_text(encoding="utf-8")

    gradle, n_min = re.subn(
        r"minSdk\s*=\s*flutter\.minSdkVersion",
        "minSdk = maxOf(flutter.minSdkVersion, {0})".format(MIN_SDK),
        gradle,
        count=1,
    )
    gradle, n_compile = re.subn(
        r"compileSdk\s*=\s*flutter\.compileSdkVersion",
        "compileSdk = maxOf(flutter.compileSdkVersion, {0})".format(COMPILE_SDK),
        gradle,
        count=1,
    )
    if n_compile == 0 and "compileSdk = maxOf(" not in gradle:
        # Certaines versions ecrivent un nombre en dur.
        gradle, n_compile = re.subn(
            r"compileSdk\s*=\s*\d+",
            "compileSdk = {0}".format(COMPILE_SDK),
            gradle,
            count=1,
        )

    gradle_kts.write_text(gradle, encoding="utf-8")
    print("Gradle (Kotlin DSL) : minSdk >= {0} ({1} remplacement), "
          "compileSdk >= {2} ({3} remplacement).".format(
              MIN_SDK, n_min, COMPILE_SDK, n_compile))
elif gradle_groovy.exists():
    gradle = gradle_groovy.read_text(encoding="utf-8")
    gradle = re.sub(
        r"minSdkVersion\s+flutter\.minSdkVersion",
        "minSdkVersion Math.max(flutter.minSdkVersion, {0})".format(MIN_SDK),
        gradle,
        count=1,
    )
    gradle = re.sub(
        r"compileSdkVersion\s+flutter\.compileSdkVersion",
        "compileSdkVersion {0}".format(COMPILE_SDK),
        gradle,
        count=1,
    )
    gradle_groovy.write_text(gradle, encoding="utf-8")
    print("Gradle (Groovy) : minSdk et compileSdk ajustes.")
else:
    print("Attention : build.gradle Android introuvable, SDK non verifie.")

# --------------------------------------------------------------------------
# 5 bis. Signature de l'APK.
#
#     Sans cle, Gradle signe avec une cle de debogage regeneree a chaque
#     compilation : deux APK successifs ont donc des signatures differentes, et
#     Android refuse la mise a jour. Il faut desinstaller a chaque fois, en
#     perdant les donnees.
#
#     Avec une cle stable, les mises a jour s'installent par-dessus.
#     La cle n'est jamais dans le depot : elle arrive par les secrets de la
#     forge, et le fichier key.properties est ecrit juste avant la
#     compilation. En son absence, on retombe sur la signature de debogage
#     pour que le projet reste compilable par n'importe qui.
# --------------------------------------------------------------------------
if gradle_kts.exists():
    gradle = gradle_kts.read_text(encoding="utf-8")

    if "keystoreProperties" not in gradle:
        entete = '''import java.util.Properties
import java.io.FileInputStream

// Cle de signature, fournie hors du depot. Absente : signature de debogage.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

'''
        gradle = entete + gradle

        signature = '''
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {'''
        gradle = gradle.replace("    defaultConfig {", signature, 1)

        gradle, remplacements = re.subn(
            r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
            'signingConfig = if (keystorePropertiesFile.exists()) '
            'signingConfigs.getByName("release") else '
            'signingConfigs.getByName("debug")',
            gradle,
            count=1,
        )
        gradle_kts.write_text(gradle, encoding="utf-8")
        print("Signature : configuration ajoutee ({0} remplacement).".format(
            remplacements))
    else:
        print("Signature : deja configuree.")

# --------------------------------------------------------------------------
# 6. Silence l'avertissement bloquant du plugin Gradle sur compileSdk 37.
# --------------------------------------------------------------------------
properties = pathlib.Path("android/gradle.properties")
if properties.exists():
    content = properties.read_text(encoding="utf-8")
    ligne = "android.suppressUnsupportedCompileSdk={0}".format(COMPILE_SDK)
    if "suppressUnsupportedCompileSdk" not in content:
        if content and not content.endswith("\n"):
            content += "\n"
        content += ligne + "\n"
        properties.write_text(content, encoding="utf-8")
        print("gradle.properties : avertissement compileSdk neutralise.")
    else:
        print("gradle.properties : deja configure.")
else:
    properties.write_text(
        "android.suppressUnsupportedCompileSdk={0}\n".format(COMPILE_SDK),
        encoding="utf-8",
    )
    print("gradle.properties cree.")
