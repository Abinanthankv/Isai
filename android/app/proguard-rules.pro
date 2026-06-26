# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# FFmpegKit
-keep class com.arthenica.** { *; }
-keepclassmembers class com.arthenica.** { *; }

# Media3/ExoPlayer (often needed for just_audio / audio_service)
-keep class androidx.media3.** { *; }
-keepclassmembers class androidx.media3.** { *; }

# Fix R8 warnings about Flutter deferred components
-dontwarn com.google.android.play.core.**

# audio_service
-keep class com.ryanheise.audioservice.** { *; }
-keepclassmembers class com.ryanheise.audioservice.** { *; }

# just_audio
-keep class com.ryanheise.just_audio.** { *; }
-keepclassmembers class com.ryanheise.just_audio.** { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }

# flutter_js (protect native bridge and JavascriptRuntime)
-keep class com.jhomlala.flutter_js.** { *; }
-dontwarn com.jhomlala.flutter_js.**

-keep class androidx.lifecycle.** { *; }
-keepclassmembers class androidx.lifecycle.** { *; }

# AndroidX Media (used by audio_service for MediaSession, MediaStyle)
-keep class android.support.v4.media.** { *; }
-keep class android.support.v4.media.session.** { *; }
-keepclasseswithmembers class android.support.v4.media.** { *; }
-keepclasseswithmembers class android.support.v4.media.session.** { *; }

# AndroidX core NotificationCompat
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }
-keep class androidx.core.app.ServiceCompat { *; }
-keep class androidx.media.app.NotificationCompat { *; }
