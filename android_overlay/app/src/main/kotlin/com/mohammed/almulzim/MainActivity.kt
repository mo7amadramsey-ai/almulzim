package com.mohammed.almulzim

import android.Manifest
import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.provider.Settings
import android.telecom.TelecomManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Empty receiver: lets the app be registered as Device Owner via adb (true kiosk lock)
class FocusAdmin : DeviceAdminReceiver()

// Strict session (study timer OR focus video). The session lives in native storage so it survives
// an app kill / reboot.
//  - type "study": wall-clock session with a hard end time (can never lock longer than planned)
//  - other types ("web", "moodle", "local"): the time left only counts down while the video plays
class MainActivity : FlutterFragmentActivity() {
    private lateinit var channel: MethodChannel
    private var listening = false
    private var incoming: String? = null // file opened from Drive / another app

    private val prefs by lazy { getSharedPreferences("strict", MODE_PRIVATE) }

    private val maxMs = 21600000L // 6 hours

    private fun leftMs() = prefs.getLong("left", 0L)
    private fun endAt() = prefs.getLong("endAt", 0L)
    private fun isClock() = prefs.getString("type", "") == "study"
    private fun sessionActive() = leftMs() > 0L && (endAt() == 0L || System.currentTimeMillis() < endAt())

    // Android 12+: while a session is active, other apps' floating windows are hidden over our app
    private fun applyOverlayBlock() {
        if (Build.VERSION.SDK_INT >= 31) {
            try { window.setHideOverlayWindows(sessionActive()) } catch (e: Exception) {}
        }
    }

    private fun startSession(ms: Long, type: String?, target: String?) {
        val left = ms.coerceIn(1L, maxMs)
        val clock = type == "study"
        prefs.edit()
            .putLong("left", left)
            .putLong("endAt", if (clock) System.currentTimeMillis() + left else 0L)
            .putString("type", type)
            .putString("target", target)
            .apply()
        enforceLock()
        applyOverlayBlock()
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "focus_lock")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startLock" -> {
                    startSession((call.argument<Number>("left"))!!.toLong(), call.argument<String>("type"), call.argument<String>("target"))
                    askPermissions()
                    listenCalls()
                    result.success(true)
                }
                "extendLock" -> {
                    startSession((call.argument<Number>("left"))!!.toLong(), prefs.getString("type", "study"), prefs.getString("target", ""))
                    result.success(true)
                }
                // Dart reports the remaining time every few seconds
                "setLeft" -> {
                    if (prefs.contains("type")) {
                        prefs.edit().putLong("left", (call.argument<Number>("left"))!!.toLong().coerceIn(0L, maxMs)).apply()
                    }
                    result.success(true)
                }
                // Strict mode switched to another video of the same folder: remember it for resume
                "setTarget" -> {
                    if (sessionActive()) prefs.edit().putString("target", call.argument<String>("target")).apply()
                    result.success(true)
                }
                // Timer ended: release kiosk mode. Video sessions keep their data so they can be extended.
                "releaseLock" -> {
                    if (isClock()) prefs.edit().clear().apply() else prefs.edit().putLong("left", 0L).apply()
                    applyOverlayBlock()
                    try { stopLockTask() } catch (e: Exception) {}
                    result.success(true)
                }
                "stopLock" -> {
                    prefs.edit().clear().apply()
                    applyOverlayBlock()
                    try { stopLockTask() } catch (e: Exception) {}
                    result.success(true)
                }
                // The saved session, so Dart can resume it after a restart
                "getSession" -> {
                    if (sessionActive()) {
                        listenCalls()
                        val byClock = if (endAt() > 0L) endAt() - System.currentTimeMillis() else leftMs()
                        result.success(mapOf(
                            "left" to minOf(leftMs(), byClock),
                            "type" to prefs.getString("type", ""),
                            "target" to prefs.getString("target", "")
                        ))
                    } else {
                        prefs.edit().clear().apply()
                        result.success(null)
                    }
                }
                // Path of a file that another app (Drive) sent to us, once
                "takeIncoming" -> {
                    val p = incoming
                    incoming = null
                    result.success(p)
                }
                "answerCall" -> {
                    if (hasPerm(Manifest.permission.ANSWER_PHONE_CALLS)) {
                        getSystemService(TelecomManager::class.java).acceptRingingCall()
                    }
                    result.success(true)
                }
                "isAccessibilityEnabled" -> {
                    val on = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
                    result.success(on.contains("$packageName/"))
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                // Emergency calls stay possible: opens the phone's dialer
                "openDialer" -> {
                    startActivity(Intent(Intent.ACTION_DIAL).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                // Opens ONLY the Google Drive app (never a browser or other app)
                "openDrive" -> {
                    val i = packageManager.getLaunchIntentForPackage("com.google.android.apps.docs")
                    if (i != null) {
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    } else {
                        result.success(false) // Drive not installed
                    }
                }
                // Public storage access (videos/documents survive uninstall and show in file managers)
                "hasAllFiles" -> {
                    result.success(
                        if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager()
                        else hasPerm(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    )
                }
                "requestAllFiles" -> {
                    if (Build.VERSION.SDK_INT >= 30) {
                        try {
                            startActivity(Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:$packageName")))
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                        }
                    } else {
                        ActivityCompat.requestPermissions(this,
                            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE), 2)
                    }
                    result.success(true)
                }
                // True only when OUR window has the focus and is not floating / split-screen
                "isFocused" -> {
                    val multi = Build.VERSION.SDK_INT >= 24 && isInMultiWindowMode
                    result.success(hasWindowFocus() && !multi)
                }
                "notify" -> {
                    Notifier.show(this, (call.argument<Number>("id"))!!.toInt(), call.argument<String>("title") ?: "", call.argument<String>("body") ?: "")
                    result.success(true)
                }
                "schedule" -> {
                    Notifier.schedule(this, (call.argument<Number>("id"))!!.toInt(), (call.argument<Number>("at"))!!.toLong(),
                        call.argument<String>("title") ?: "", call.argument<String>("body") ?: "")
                    result.success(true)
                }
                "cancelReminder" -> {
                    Notifier.cancel(this, (call.argument<Number>("id"))!!.toInt())
                    result.success(true)
                }
                "requestNotifPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 77)
                    }
                    result.success(true)
                }
                "isDeviceOwner" -> {
                    result.success(getSystemService(DevicePolicyManager::class.java).isDeviceOwnerApp(packageName))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        grabIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        grabIntent(intent)
    }

    // Copies a file shared/opened from Drive into our cache so Dart can import it
    @Suppress("DEPRECATION")
    private fun grabIntent(i: Intent?) {
        if (i == null) return
        val uri: Uri = when (i.action) {
            Intent.ACTION_VIEW -> i.data
            Intent.ACTION_SEND -> i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            else -> null
        } ?: return
        try {
            var name = "file"
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                val ix = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (ix >= 0 && c.moveToFirst()) name = c.getString(ix) ?: "file"
            }
            val dir = File(cacheDir, "incoming")
            dir.mkdirs()
            val out = File(dir, name.replace(Regex("[/:*?<>|]"), "_"))
            contentResolver.openInputStream(uri)?.use { inp -> out.outputStream().use { inp.copyTo(it) } }
            incoming = out.absolutePath
        } catch (e: Exception) {}
    }

    // Re-enter lock whenever the app comes back during an active session
    override fun onResume() {
        super.onResume()
        startFloatWatch()
        applyOverlayBlock()
        if (sessionActive()) enforceLock()
    }

    // Watches (every second) whether OUR window became floating / split-screen; if so the task is
    // removed and LockService re-opens the app full screen.
    private val floatHandler = Handler(Looper.getMainLooper())
    private var watching = false
    private val floatCheck = object : Runnable {
        override fun run() {
            if (sessionActive() && Build.VERSION.SDK_INT >= 24 && isInMultiWindowMode) {
                val now = System.currentTimeMillis()
                if (now - prefs.getLong("fixAt", 0L) > 3000) { // guard against loops
                    prefs.edit().putLong("fixAt", now).apply()
                    finishAndRemoveTask()
                    return
                }
            }
            floatHandler.postDelayed(this, 1000)
        }
    }

    private fun startFloatWatch() {
        if (!watching) { watching = true; floatHandler.postDelayed(floatCheck, 1000) }
    }

    override fun onDestroy() {
        floatHandler.removeCallbacks(floatCheck)
        watching = false
        super.onDestroy()
    }

    private fun enforceLock() {
        val dpm = getSystemService(DevicePolicyManager::class.java)
        if (dpm.isDeviceOwnerApp(packageName)) {
            // Device Owner = real kiosk. The dialer (and Drive) are whitelisted.
            val admin = ComponentName(this, FocusAdmin::class.java)
            val dialer = try { getSystemService(TelecomManager::class.java).defaultDialerPackage } catch (e: Exception) { null }
            dpm.setLockTaskPackages(admin, listOfNotNull(packageName, dialer, "com.google.android.apps.docs").toTypedArray())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) dpm.setLockTaskFeatures(admin, 0)
            try { startLockTask() } catch (e: Exception) {}
        }
        // Not Device Owner: the accessibility service (LockService) does the enforcing instead.
    }

    private fun hasPerm(p: String) =
        ContextCompat.checkSelfPermission(this, p) == PackageManager.PERMISSION_GRANTED

    private fun askPermissions() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ANSWER_PHONE_CALLS, Manifest.permission.READ_PHONE_STATE),
            1
        )
    }

    // Send call state to Flutter (1 = ringing)
    private fun listenCalls() {
        if (listening || !hasPerm(Manifest.permission.READ_PHONE_STATE)) return
        listening = true
        val tm = getSystemService(TelephonyManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            tm.registerTelephonyCallback(mainExecutor, object : TelephonyCallback(),
                TelephonyCallback.CallStateListener {
                override fun onCallStateChanged(state: Int) {
                    channel.invokeMethod("callState", state)
                }
            })
        } else {
            @Suppress("DEPRECATION")
            tm.listen(object : PhoneStateListener() {
                @Deprecated("old api")
                override fun onCallStateChanged(state: Int, number: String?) {
                    channel.invokeMethod("callState", state)
                }
            }, PhoneStateListener.LISTEN_CALL_STATE)
        }
    }
}
