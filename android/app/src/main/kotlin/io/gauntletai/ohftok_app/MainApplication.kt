package io.gauntletai.ohftok_app

import io.flutter.app.FlutterApplication
import androidx.multidex.MultiDexApplication
import androidx.multidex.MultiDex
import android.content.Context

class MainApplication : MultiDexApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }
} 