package ru.apsolutions.calenfi

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ListenableWorker
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

/// Фоновая синхронизация календарей.
///
/// Android замораживает приложение примерно через минуту после ухода с экрана
/// и режет ему сеть, поэтому таймер внутри приложения в фоне не работает:
/// встречи обновлялись, только пока Calenfi открыт. Системный планировщик
/// раз в 15 минут (чаще Android не позволяет) будит процесс, когда есть сеть,
/// и запускает Dart-функцию `calenfiBackgroundSync` в отдельном движке без
/// интерфейса. Она синхронизирует просроченные аккаунты, обновляет домашний
/// виджет и напоминания и сообщает «done».
class BackgroundSyncWorker(context: Context, params: WorkerParameters) :
    ListenableWorker(context, params) {

    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null

    override fun startWork(): ListenableFuture<Result> =
        CallbackToFutureAdapter.getFuture { completer ->
            main.post {
                try {
                    val loader = FlutterInjector.instance().flutterLoader()
                    loader.startInitialization(applicationContext)
                    loader.ensureInitializationComplete(applicationContext, null)
                    val created = FlutterEngine(applicationContext)
                    engine = created
                    MethodChannel(created.dartExecutor.binaryMessenger, CHANNEL)
                        .setMethodCallHandler { call, result ->
                            if (call.method == "done") {
                                result.success(null)
                                release()
                                completer.set(Result.success())
                            } else {
                                result.notImplemented()
                            }
                        }
                    created.dartExecutor.executeDartEntrypoint(
                        DartExecutor.DartEntrypoint(
                            loader.findAppBundlePath(),
                            ENTRYPOINT,
                        ),
                    )
                } catch (error: Throwable) {
                    release()
                    completer.set(Result.failure())
                }
            }
            "calenfi-background-sync"
        }

    /// Система отбирает время (лимит 10 минут) или пропала сеть.
    override fun onStopped() {
        main.post { release() }
    }

    private fun release() {
        engine?.destroy()
        engine = null
    }

    companion object {
        private const val CHANNEL = "ru.apsolutions.calenfi/background"
        private const val ENTRYPOINT = "calenfiBackgroundSync"
        private const val WORK_NAME = "calenfi-background-sync"

        /// Ставит периодическую задачу. Вызывается при каждом запуске
        /// приложения, после обновления пакета и после перезагрузки:
        /// повторная постановка с тем же именем задачу не дублирует.
        fun schedule(context: Context) {
            val request = PeriodicWorkRequest.Builder(
                BackgroundSyncWorker::class.java,
                15,
                TimeUnit.MINUTES,
            )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .build()
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.UPDATE,
                    request,
                )
        }
    }
}
