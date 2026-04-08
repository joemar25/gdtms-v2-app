# Flutter Wrapper
-dontwarn com.google.android.play.core.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_image_compress native components
-keep class top.flutters.image_compress.** { *; }
-keep class com.example.flutter_image_compress.** { *; }

# image_picker native components
-keep class io.flutter.plugins.imagepicker.** { *; }

# To prevent R8 from stripping away native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
