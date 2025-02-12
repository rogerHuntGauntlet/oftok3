package io.gauntletai.ohftok_app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ConfigMethodChannel(flutterEngine: FlutterEngine) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.gauntletai.ohftok_app/config")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getReplicateApiToken" -> {
                    result.success(BuildConfig.REPLICATE_API_TOKEN)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
} 