# Android native config

`flutter create .` generates `android/` for you, matched to the Flutter/Gradle/
Android Studio versions on your machine — don't hand-copy someone else's
`android/` folder, just make these specific edits to the one it generates.

## 1. `android/app/src/main/AndroidManifest.xml`

Inside the `<application>` tag, add AdMob's required App ID meta-data. The
value below is Google's public **test** App ID — safe to ship while you're
developing, but swap it for your real AdMob App ID before release (Testing
your Ads guide: https://developers.google.com/admob/flutter/quick-start).

```xml
<application ...>
    <meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
</application>
```

Also add, above `<application>`, the internet + network-state permissions
(most fresh Flutter projects already have `INTERNET`; ads need it too, and
push needs network-state):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

## 2. `android/app/build.gradle.kts` (or `build.gradle`)

Make sure these two lines are set — `google_mobile_ads` and `onesignal_flutter`
both need a modern minSdk (check each package's current pub.dev page before
you build, in case this has crept up since this was written):

```
minSdk = 21          // or higher — verify against current package docs
targetSdk = flutter.targetSdkVersion
```

## 3. Run it

```
flutter pub get
flutter run
```

If a build fails on a Gradle/AGP or Kotlin version mismatch, it's almost
always because the plugin versions in `pubspec.yaml` want a newer Gradle/AGP
than the one `flutter create` scaffolded — running `flutter run` again after
accepting Android Studio's "upgrade Gradle" prompt usually fixes it.

## Later, for the Play Store build

Not needed yet — this is here so you know it's coming. Once the app itself is
tested and working, the next steps are: a release signing keystore, filling in
`android/key.properties`, and `flutter build appbundle --release`. Ask me when
you're ready for that part and I'll walk it through with you.
