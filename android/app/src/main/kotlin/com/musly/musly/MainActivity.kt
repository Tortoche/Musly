package com.devid.musly

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : AudioServiceFragmentActivity() {
    private val CHANNEL = "com.devid.musly/ytdlp"
    private val TV_CHANNEL = "com.devid.musly/tv_mode"
    private val APK_CHANNEL = "com.devid.musly/apk_installer"
    private val DEEP_LINK_CHANNEL = "com.devid.musly/deep_link"
    private val VOICE_SEARCH_CHANNEL = "com.devid.musly/voice_search"

    private var initialLink: String? = null
    private var deepLinkChannel: MethodChannel? = null
    private var initialVoiceQuery: String? = null
    private var voiceSearchChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return
        var link: String? = null
        if (Intent.ACTION_VIEW == intent.action) {
            link = intent.dataString
        } else if (Intent.ACTION_SEND == intent.action && "text/plain" == intent.type) {
            link = intent.getStringExtra(Intent.EXTRA_TEXT)
        }

        if (!link.isNullOrEmpty()) {
            initialLink = link
            deepLinkChannel?.invokeMethod("onNewLink", link)
        }

        if (intent.action == "android.media.action.MEDIA_PLAY_FROM_SEARCH" ||
            intent.action == "android.intent.action.MEDIA_SEARCH") {
            val query = intent.getStringExtra(android.app.SearchManager.QUERY)
                ?: intent.getStringExtra("query")
                ?: intent.getStringExtra(android.provider.MediaStore.EXTRA_MEDIA_TITLE)
                ?: intent.getStringExtra(android.provider.MediaStore.EXTRA_MEDIA_ARTIST)
                ?: ""
            initialVoiceQuery = query
            voiceSearchChannel?.invokeMethod("onVoiceSearch", query)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native Deep Link channel
        val linkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
        deepLinkChannel = linkChannel
        linkChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    val link = initialLink
                    initialLink = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }
        if (!initialLink.isNullOrEmpty()) {
            deepLinkChannel?.invokeMethod("onNewLink", initialLink)
        }

        // Voice search channel for Google Assistant & Android Auto
        val voiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_SEARCH_CHANNEL)
        voiceSearchChannel = voiceChannel
        voiceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialVoiceQuery" -> {
                    val q = initialVoiceQuery
                    initialVoiceQuery = null
                    result.success(q)
                }
                else -> result.notImplemented()
            }
        }
        if (initialVoiceQuery != null) {
            voiceSearchChannel?.invokeMethod("onVoiceSearch", initialVoiceQuery)
        }

        // Native APK installer channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath") ?: ""
                try {
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file not found: $filePath", null)
                        return@setMethodCallHandler
                    }

                    val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                    } else {
                        Uri.fromFile(file)
                    }

                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Native Android TV & TV Box detection
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isTvDevice") {
                var isTv = false
                try {
                    val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                    if (uiModeManager != null && uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
                        isTv = true
                    }
                    if (!isTv && packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)) {
                        isTv = true
                    }
                    if (!isTv && packageManager.hasSystemFeature("android.hardware.type.television")) {
                        isTv = true
                    }
                    if (!isTv && !packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)) {
                        isTv = true
                    }
                    if (!isTv) {
                        val model = (Build.MODEL ?: "").lowercase()
                        val hardware = (Build.HARDWARE ?: "").lowercase()
                        val brand = (Build.BRAND ?: "").lowercase()
                        val fingerprint = (Build.FINGERPRINT ?: "").lowercase()
                        val tvKeywords = listOf("tv", "box", "firetv", "shield", "bravia", "chromecast", "mibox", "amlogic", "allwinner", "rk3328", "rk3399", "stick")
                        for (kw in tvKeywords) {
                            if (model.contains(kw) || hardware.contains(kw) || brand.contains(kw) || fingerprint.contains(kw)) {
                                isTv = true
                                break
                            }
                        }
                    }
                } catch (e: Exception) {
                    isTv = false
                }
                result.success(isTv)
            } else {
                result.notImplemented()
            }
        }

        try {
            if (!Python.isStarted()) {
                Python.start(AndroidPlatform(this))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val py = Python.getInstance()
                    val helper = py.getModule("ytdlp_helper")
                    when (call.method) {
                        "getStreamUrl" -> {
                            val videoId = call.argument<String>("videoId") ?: ""
                            val url = helper.callAttr("get_stream_url", videoId).toString()
                            withContext(Dispatchers.Main) { result.success(url) }
                        }
                        "search" -> {
                            val query = call.argument<String>("query") ?: ""
                            val limit = call.argument<Int>("limit") ?: 25
                            val json = helper.callAttr("search", query, limit).toString()
                            withContext(Dispatchers.Main) { result.success(json) }
                        }
                        "searchDual" -> {
                            val query = call.argument<String>("query") ?: ""
                            val limit = call.argument<Int>("limit") ?: 20
                            val json = helper.callAttr("search_dual", query, limit).toString()
                            withContext(Dispatchers.Main) { result.success(json) }
                        }
                        "getVideoInfo" -> {
                            val videoId = call.argument<String>("videoId") ?: ""
                            val json = helper.callAttr("get_video_info", videoId).toString()
                            withContext(Dispatchers.Main) { result.success(json) }
                        }
                        "getPlaylist" -> {
                            val playlistId = call.argument<String>("playlistId") ?: ""
                            val limit = call.argument<Int>("limit") ?: 100
                            val json = helper.callAttr("get_playlist", playlistId, limit).toString()
                            withContext(Dispatchers.Main) { result.success(json) }
                        }
                        "isAvailable" -> {
                            withContext(Dispatchers.Main) { result.success(true) }
                        }
                        else -> {
                            withContext(Dispatchers.Main) { result.notImplemented() }
                        }
                    }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        result.error("YTDLP_ERROR", e.message, e.stackTraceToString())
                    }
                }
            }
        }
    }
}
