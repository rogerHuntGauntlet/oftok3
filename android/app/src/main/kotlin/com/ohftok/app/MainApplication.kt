package io.gauntletai.ohftok_app

import androidx.multidex.MultiDexApplication
import androidx.multidex.MultiDex
import android.content.Context
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.ConnectionResult

class MainApplication : MultiDexApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }

    override fun onCreate() {
        super.onCreate()
        
        // Initialize Google Play Services
        try {
            val availability = GoogleApiAvailability.getInstance()
            val resultCode = availability.isGooglePlayServicesAvailable(this)
            if (resultCode != ConnectionResult.SUCCESS) {
                // Log the error instead of trying to show a dialog
                // since we can't show UI from the Application class
                android.util.Log.e("MainApplication", 
                    "Google Play Services is not available: $resultCode")
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
} 