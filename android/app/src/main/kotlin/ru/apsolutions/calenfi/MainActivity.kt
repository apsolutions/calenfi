package ru.apsolutions.calenfi

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AccountSyncChannel.attach(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.apsolutions.calenfi/background")
            .setMethodCallHandler { call, result ->
                if (call.method == "schedulePredictive") {
                    BackgroundSyncWorker.schedulePredictive(this, call.argument<Number>("at")?.toLong())
                    result.success(null)
                } else if (!AccountSyncChannel.handle(flutterEngine, call, result)) {
                    result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Фоновая синхронизация: см. BackgroundSyncWorker.
        BackgroundSyncWorker.schedule(this)
    }
}
