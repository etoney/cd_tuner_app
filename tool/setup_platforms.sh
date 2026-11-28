#!/usr/bin/env bash
# One-time setup: generates the iOS and Android project folders around the
# app code, then adds the settings the tuner and metronome need.
# Run from anywhere on a Mac with Flutter and Xcode installed:
#   bash tool/setup_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create \
  --org com.castledangermusic \
  --project-name cd_tuner_app \
  --platforms ios,android \
  .

# Bundle ID used in App Store Connect / TestFlight.
perl -pi -e 's/PRODUCT_BUNDLE_IDENTIFIER = com\.castledangermusic\.cdTunerApp/PRODUCT_BUNDLE_IDENTIFIER = com.castledangermusic.tempustuner/g' ios/Runner.xcodeproj/project.pbxproj

PLIST=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy
# Microphone prompt text (required, or iOS closes the app when the tuner listens).
$PB -c "Delete :NSMicrophoneUsageDescription" "$PLIST" 2>/dev/null || true
$PB -c "Add :NSMicrophoneUsageDescription string 'The tuner listens to your instrument to measure its pitch.'" "$PLIST"
# Background audio, so the metronome keeps ticking on the lock screen.
$PB -c "Delete :UIBackgroundModes" "$PLIST" 2>/dev/null || true
$PB -c "Add :UIBackgroundModes array" "$PLIST"
$PB -c "Add :UIBackgroundModes:0 string audio" "$PLIST"
# App name under the icon.
$PB -c "Set :CFBundleDisplayName 'Tempus Tuner'" "$PLIST" 2>/dev/null || true

# No custom encryption, so TestFlight doesn't ask about export compliance each build.
$PB -c "Delete :ITSAppUsesNonExemptEncryption" "$PLIST" 2>/dev/null || true
$PB -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"

# App icon: the Castle Danger crest (single 1024 px image; Xcode makes the rest).
ICONS=ios/Runner/Assets.xcassets/AppIcon.appiconset
rm -f "$ICONS"/*.png
cp tool/ios/icon-1024.png "$ICONS/icon-1024.png"
cat > "$ICONS/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

# Portrait only (the screens are laid out for a phone held upright).
$PB -c "Delete :UISupportedInterfaceOrientations" "$PLIST" 2>/dev/null || true
$PB -c "Add :UISupportedInterfaceOrientations array" "$PLIST"
$PB -c "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait" "$PLIST"

# iPhone only: the screens are laid out for a phone (no iPad screenshots needed).
perl -pi -e 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = 1;/g' ios/Runner.xcodeproj/project.pbxproj

# Bundle the fonts (no download needed on first launch).
bash tool/fetch_fonts.sh

# Android app icons (adaptive foreground/background + legacy sizes).
cp -R tool/android/res/. android/app/src/main/res/

# Android: app label, and minimum Android 6.0 (the audio engine needs it).
perl -pi -e 's/android:label="cd_tuner_app"/android:label="Tempus Tuner"/' android/app/src/main/AndroidManifest.xml
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && perl -pi -e 's/minSdk(Version)?\s*=?\s*flutter\.minSdkVersion/minSdk = 23/' "$f"
done

flutter pub get
echo
echo "Done. Plug in your phone and run:  flutter run --release"
