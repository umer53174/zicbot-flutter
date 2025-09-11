# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

# Local notifications plugin
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Shared preferences
-keep class com.tekartik.sqflite.** { *; }
-keep class android.app.SharedPreferencesImpl { *; }

# HTTP client
-keep class org.apache.** { *; }
-keep class org.json.** { *; }

# Play Core (required for deferred components / dynamic delivery)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep relevant annotations
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes Signature

# Keep all classes that might be accessed via reflection
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.app.Application
-keep class * extends android.app.Activity


# url_launcher plugin
-keep class io.flutter.plugins.urllauncher.** { *; }