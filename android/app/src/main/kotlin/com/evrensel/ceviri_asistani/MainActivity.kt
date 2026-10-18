package com.evrensel.ceviri_asistani

import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), MessageClient.OnMessageReceivedListener {

    private val CHANNEL_NAME = "com.evrensel.ceviri_asistani/saat"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
    }

    override fun onResume() {
        super.onResume()
        Wearable.getMessageClient(this).addListener(this)
    }

    override fun onPause() {
        super.onPause()
        Wearable.getMessageClient(this).removeListener(this)
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        val path = messageEvent.path
        val payload = if (messageEvent.data != null && messageEvent.data.isNotEmpty()) {
            String(messageEvent.data, Charsets.UTF_8)
        } else {
            ""
        }
        val finalMessage = if (payload.isNotEmpty() && !path.contains(payload)) {
            "$path/$payload"
        } else {
            path
        }

        runOnUiThread {
            methodChannel?.invokeMethod("onWearMessage", finalMessage)
        }
    }
}
