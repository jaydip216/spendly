package com.spendly.app.spendly

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
	}

	companion object {
		private const val CHANNEL = "spendly/sms_receiver"
		private var methodChannel: MethodChannel? = null

		fun pushIncomingSmsToFlutter(sender: String, body: String, timestampMs: Long) {
			methodChannel?.invokeMethod(
				"onSmsReceived",
				mapOf(
					"sender" to sender,
					"body" to body,
					"timestampMs" to timestampMs,
				)
			)
		}
	}
}
