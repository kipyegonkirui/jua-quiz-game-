# App icon and splash

Unzip over the project root. No SQL. Needs a full stop and `flutter run` (not hot reload); uninstall the old app first if the launcher still shows the old icon.

- Android: adaptive icon (gradient background + logo foreground), legacy icons for old phones, splash = blue gradient + logo.
- iOS: all AppIcon sizes (opaque, no transparency, as App Store requires).
- Web: favicon and PWA icons.
- `assets/ui/jua_logo.png`: full logo for use inside the app (already covered by the `assets/ui/` line in pubspec).
- `store/play_store_icon_512.png`: upload this in Play Console.

One manual line (not shipped, so your AndroidManifest.xml is not overwritten):
in `android/app/src/main/AndroidManifest.xml` change `android:label="jua_quiz"` to `android:label="Jua Quiz"`.
