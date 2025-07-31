# Flutter-specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.plugins.**

# Aturan untuk Firebase
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-keepattributes Signature, InnerClasses, EnclosingMethod, Exceptions

# Aturan untuk library HTTP dan JSON serialization
-keep class org.bouncycastle.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes *Annotation*

# Aturan untuk library yang Anda gunakan (seperti local_auth)
-keep class androidx.appcompat.app.AppCompatDialogFragment { *; }

# --- ATURAN BARU UNTUK MENGATASI ERROR R8 ---
# Ini akan mencegah ProGuard membuang kelas Google Play Core.
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Mencegah obfuskasi model data Anda (opsional tapi sangat direkomendasikan)
-keep class com.helpdesk.anri.models.** { *; }