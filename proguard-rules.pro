# ProGuard / R8 keep rules for Synesthesia Android release builds.
# Godot's Gradle template does not enable minification by default; these rules
# ensure the engine's JNI bridge, the app's GodotApp activity, and native
# methods (Rust GDExtension .so) survive R8 shrinking.

# Godot engine JNI classes — must not be stripped or renamed.
-keep class org.godotengine.** { *; }
-dontwarn org.godotengine.**

# App's GodotApp activity and package.
-keep class com.godot.** { *; }

# Native methods (JNI bridge to Rust GDExtension .so).
-keepclasseswithmembernames class * {
    native <methods>;
}

# Android entry-point classes.
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Godot plugin classes (future-proofing for dynamic loading).
-keep class ** extends org.godotengine.godot.plugin.GodotPlugin { *; }
