package ru.apsolutions.calenfi

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** One coordinator per application process, independent of Dart isolates. */
internal object AccountSyncChannel {
    private val coordinator = AccountSyncCoordinator()

    fun attach(engine: FlutterEngine) {
        engine.addEngineLifecycleListener(object : FlutterEngine.EngineLifecycleListener {
            override fun onPreEngineRestart() { coordinator.dropOwner(engine) }
            override fun onEngineWillDestroy() { coordinator.dropOwner(engine) }
        })
    }

    fun handle(engine: FlutterEngine, call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method != "acquireAccount" && call.method != "releaseAccount") return false
        val account = call.argument<String>("account")
        val token = call.argument<String>("token")
        if (account.isNullOrEmpty() || token.isNullOrEmpty()) {
            result.error("invalid-lock", "Account and token are required", null)
            return true
        }
        if (call.method == "acquireAccount") {
            coordinator.acquire(account, engine, token) { result.success(null) }
        } else {
            coordinator.release(account, engine, token)
            result.success(null)
        }
        return true
    }
}
