# flutter_local_notifications stores scheduled reminders with Gson; keep the
# generic type info so they still load after a reboot or app update.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
