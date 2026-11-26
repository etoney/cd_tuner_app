# CD Tuner

A free tuner and metronome for guitar and bass by Castle Danger Music Company, for iOS and Android.

## What it does

**Tuner**
- 6, 7 and 8-string guitar; 4, 5 and 6-string bass (down to a 5-string's low B0, 30.87 Hz)
- Auto mode finds the string you're playing; Manual locks to the peg you tap on the headstock
- Preset tunings for every setup, plus custom tunings: set any string to any note and octave, fine-tune in cents, save, edit, delete
- Calibration from A = 415 to 466 Hz, and a reference tone for tuning by ear

**Metronome**
- 20–300 BPM with − / + buttons, a drag dial and tap tempo
- 16 time signatures including 2/2, 5/4, 7/8, 11/8, 13/8 and 15/16, with accents set by grouping (7/8 = 2+2+3)
- Tap any beat lamp to cycle accent → click → soft → off
- Subdivisions (eighths, triplets, sixteenths) and 8 click sounds
- **Keeps ticking with the phone locked** (iOS background audio; Android foreground service with a Stop button in the notification)

## How it's built

| Part | Where |
| --- | --- |
| Screens (Flutter) | `lib/screens/` |
| Tunings, custom tunings, saved settings | `lib/data/tunings.dart` |
| Metronome settings and time signatures | `lib/data/metronome.dart` |
| Rusted-iron look: plates, parchment, lamps, oval buttons | `lib/ui/style.dart` |
| Art cut from the Castle Danger designs | `assets/images/` |
| Native audio engine (local plugin) | `packages/cdmc_audio/` |

All timing-critical audio is native. The metronome mixes its clicks into the output stream at exact sample positions (Swift `AVAudioSourceNode` on iOS, a high-priority `AudioTrack` thread on Android), so tempo never depends on the UI and keeps going in the background. Pitch detection uses the YIN algorithm on an 8192-sample window, about ten readings a second.

## First-time setup (Mac)

You need [Flutter](https://docs.flutter.dev/get-started/install/macos), Xcode and Android Studio.

```bash
git clone https://github.com/etoney/cd_tuner_app.git
cd cd_tuner_app
bash tool/setup_platforms.sh
```

The script runs `flutter create` to generate the `ios/` and `android/` folders around the app code, then adds the microphone permission text and the background-audio setting to the iOS project. Commit the generated folders afterwards so everyone builds the same project.

Then plug in a phone and run:

```bash
flutter run --release
```

Use `--release` when checking the metronome; debug builds are slower.

## Testing checklist

- Tuner: play each open string in Auto; tap pegs in Manual; try a 5-string bass B0
- Metronome: start it, lock the phone, and check it keeps time; on Android, stop it from the notification
- Custom tuning: make one, save, see the Tuner aim at it, edit it, delete it
- Switch apps mid-click and come back

## TestFlight (install on your iPhone without a cable)

Every push to `main` or `app-scaffold` builds the app on GitHub, signs it and uploads it to TestFlight (`.github/workflows/testflight.yml`). One-time setup:

1. **Register the app.** In [App Store Connect](https://appstoreconnect.apple.com) choose **Apps ▸ + ▸ New App**: platform iOS, name *CD Tuner* (or any free name), language English, bundle ID **com.castledangermusic.cdtuner** (if it isn't in the list, register it first at developer.apple.com ▸ Identifiers ▸ + ▸ App IDs), SKU `cdtuner`.
2. **Create an API key.** App Store Connect ▸ **Users and Access ▸ Integrations ▸ App Store Connect API ▸ Team Keys ▸ +**. Access: **Admin** (needed so GitHub can create the signing certificate for you). Download the `.p8` file (only downloadable once) and note the **Key ID** and the **Issuer ID** shown above the list.
3. **Find your Team ID** at developer.apple.com ▸ Account ▸ Membership details.
4. **Add four secrets** in GitHub: repo ▸ **Settings ▸ Secrets and variables ▸ Actions ▸ New repository secret**:
   - `APPLE_TEAM_ID`: the Team ID
   - `ASC_KEY_ID`: the Key ID
   - `ASC_ISSUER_ID`: the Issuer ID
   - `ASC_KEY_P8`: open the `.p8` file in TextEdit and paste everything, including the BEGIN/END lines
5. **Run it.** GitHub ▸ **Actions ▸ TestFlight ▸ Run workflow** (branch `app-scaffold`). About 10 minutes later the build appears in App Store Connect ▸ TestFlight.
6. **Add yourself as a tester.** App Store Connect ▸ your app ▸ **TestFlight ▸ Internal Testing ▸ +**, create a group, add your Apple ID. Install Apple's **TestFlight** app on your iPhone and accept the invite. New builds then arrive automatically.

## Builds

GitHub Actions (`.github/workflows/build.yml`) builds an Android APK you can download from each run, and checks that the iOS app compiles. Signed iOS builds for TestFlight need your Apple signing certificate and profile added as repository secrets; that step comes later.
