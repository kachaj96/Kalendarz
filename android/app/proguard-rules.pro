# flutter_local_notifications zapisuje zaplanowane powiadomienia przez Gson.
# Bez tych reguł wersja wydaniowa (R8) potrafi wywrócić planowanie przypomnień.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Widżety są wskazywane w manifeście, ale na wszelki wypadek zostawiamy całe klasy.
-keep class com.kachaj96.kalendarz.widgets.** { *; }
