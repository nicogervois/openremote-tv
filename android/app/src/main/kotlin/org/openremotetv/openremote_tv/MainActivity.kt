package org.openremotetv.openremote_tv

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.openremotetv/network")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticast" -> {
                        val manager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        if (multicastLock == null) {
                            multicastLock = manager.createMulticastLock("openremote-discovery").apply {
                                setReferenceCounted(false)
                            }
                        }
                        multicastLock?.acquire()
                        result.success(null)
                    }
                    "releaseMulticast" -> {
                        releaseMulticast()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun releaseMulticast() {
        multicastLock?.let { if (it.isHeld) it.release() }
    }

    override fun onDestroy() {
        releaseMulticast()
        super.onDestroy()
    }
}
