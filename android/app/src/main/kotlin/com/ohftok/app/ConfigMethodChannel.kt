package com.ohftok.app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ohftok.app.BuildConfig

class ConfigMethodChannel(flutterEngine: FlutterEngine) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "config")

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