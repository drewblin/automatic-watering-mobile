package com.drewblin.automaticwatering

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "automatic_watering/mdns_resolver"
        ).setMethodCallHandler { call, result ->
            if (call.method != "resolve") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val serviceType = call.argument<String>("serviceType")
            val serviceName = call.argument<String>("serviceName")
            val localHostname = call.argument<String>("localHostname")
            val timeoutMs = call.argument<Int>("timeoutMs") ?: 5000
            if (serviceType == null || serviceName == null || localHostname == null) {
                result.success(null)
                return@setMethodCallHandler
            }
            MdnsResolver(this).resolve(
                serviceType = serviceType,
                serviceName = serviceName,
                localHostname = localHostname,
                timeoutMs = timeoutMs,
                result = result,
            )
        }
    }
}

private class MdnsResolver(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val wifiManager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    fun resolve(
        serviceType: String,
        serviceName: String,
        localHostname: String,
        timeoutMs: Int,
        result: MethodChannel.Result,
    ) {
        val targetNames = setOf(serviceName, localHostname.removeSuffix(".local"))
        val multicastLock = wifiManager.createMulticastLock("automatic-watering-mdns").apply {
            setReferenceCounted(false)
            acquire()
        }
        var completed = false

        lateinit var discoveryListener: NsdManager.DiscoveryListener

        fun finish(address: String?) {
            if (completed) return
            completed = true
            handler.removeCallbacksAndMessages(discoveryListener)
            runCatching { nsdManager.stopServiceDiscovery(discoveryListener) }
            if (multicastLock.isHeld) {
                multicastLock.release()
            }
            result.success(address)
        }

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) = Unit

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (serviceInfo.serviceType != serviceType ||
                    serviceInfo.serviceName !in targetNames
                ) {
                    return
                }
                nsdManager.resolveService(
                    serviceInfo,
                    object : NsdManager.ResolveListener {
                        override fun onResolveFailed(
                            serviceInfo: NsdServiceInfo,
                            errorCode: Int,
                        ) = Unit

                        override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                            finish(serviceInfo.host?.hostAddress)
                        }
                    },
                )
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) = Unit

            override fun onDiscoveryStopped(serviceType: String) = Unit

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                finish(null)
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                finish(null)
            }
        }

        handler.postAtTime(
            { finish(null) },
            discoveryListener,
            SystemClock.uptimeMillis() + timeoutMs,
        )
        nsdManager.discoverServices(
            serviceType,
            NsdManager.PROTOCOL_DNS_SD,
            discoveryListener,
        )
    }
}
