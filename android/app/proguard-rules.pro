# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.gson.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# MediaKit
-keep class com.alexmercerind.mediakitandroid.** { *; }
-keep class com.alexmercerind.media_kit_video.** { *; }

# Play Core
-keep class com.google.android.play.core.** { *; }

# Application models
-keep class io.gauntletai.ohftok_app.models.** { *; }
-keepclassmembers class io.gauntletai.ohftok_app.models.** { *; }

# Keep R8 rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Application classes that will be serialized/deserialized
-keep class io.gauntletai.ohftok_app.** { *; }

# Keep custom model classes
-keep class io.gauntletai.ohftok_app.models.** { *; } 