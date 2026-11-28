# Tempus Tuner

Free guitar/bass tuner + metronome for iOS (v1.0.0 submitted to the App Store Nov 2026) and
Android, by Castle Danger Music Company. Bundle ID `com.castledangermusic.tempustuner`.
The owner is a musician, not a developer: explain in plain words, never ask
them to work in Xcode, and show results on their iPhone rather than describing them.

## Layout

- Flutter app in `lib/`. Every screen is laid out on a fixed 390 x 844 canvas
  (`DesignCanvas` in `lib/ui/style.dart`) that scales to fill the screen, so
  positions are absolute `Positioned` values in those design points.
- `lib/screens/`: `tuner_screen.dart`, `metronome_screen.dart`,
  `tunings_screen.dart`, `custom_tuning_screen.dart`. `lib/main.dart` holds the
  shell, the fixed header (`PageHeader`) and the page fade (`FadeFlicker`).
- `lib/data/tunings.dart`: presets (guitar 6/7/8 incl. baritone, bass 4/5/6),
  custom tunings, the `Rig` state. `lib/data/metronome.dart`: metronome state.
- `packages/cdmc_audio/`: the native audio plugin (Kotlin for Android, Swift for
  iOS). Pitch detection is YIN with band-pass + decimation in `Yin.kt` /
  `Yin.swift` (keep both in step); reference tone and Hear It pluck in
  `RefTone.kt` / `RefTone.swift`; sample-accurate metronome in `AudioEngine`.
- Art is in `assets/images/` (the look is rusty, gothic Castle Danger style;
  new art should match). Fonts are fetched into `assets/google_fonts/` by
  `tool/fetch_fonts.sh`.
- `ios/` and `android/` are generated, not committed: run
  `bash tool/setup_platforms.sh` after cloning (it runs `flutter create`, then sets
  the bundle ID, Info.plist keys, icons, iPhone-only, and fetches fonts).

## Building

- On the owner's iPhone over USB: `flutter run --release -d <iPhone id>`
  (`flutter devices` lists it). Signing uses the Apple account signed in to Xcode;
  if needed set `DEVELOPMENT_TEAM` in `ios/Runner.xcodeproj/project.pbxproj`.
- `flutter analyze` before every push.
- Releases: pushing to `main` runs `.github/workflows/testflight.yml`, which
  builds on a GitHub Mac and uploads to TestFlight (build number = run number).
  It archives unsigned and signs at export with the App Store Connect API key
  (repo secrets), so it never creates new certificates. Bump `version` in
  `pubspec.yaml` for each App Store release.
- From April 2027 uploads must be built with Xcode 27 or later: pin it in the
  TestFlight workflow before the next release after that date.

## Store

- Privacy policy: https://castledangermusic.com/tempus-tuner-privacy/
  (the app collects no data; the mic is analysed on-device only).
- Contact: danger@castledangermusic.com
