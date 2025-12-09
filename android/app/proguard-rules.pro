# ProGuard rules for LexiFlow
# Keep Firebase and Flutter-related classes as needed

# Flutter JNI and reflection
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
# Keep Flutter deferred components manager
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
# Play Core (deferred install APIs) - optional, suppress missing warnings
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

# Prevent warnings for Kotlin metadata
-dontwarn kotlin.**