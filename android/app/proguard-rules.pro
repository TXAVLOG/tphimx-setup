# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods and classes invoked via JNI
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep plugin classes if they are needed
-keep class com.tphimx.tphimx_setup.** { *; }
