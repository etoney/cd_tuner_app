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
$PB -c "Set :CFBundleDisplayName 'CD Tuner'" "$PLIST" 2>/dev/null || true

# Portrait only (the screens are laid out for a phone held upright).
$PB -c "Delete :UISupportedInterfaceOrientations" "$PLIST" 2>/dev/null || true
$PB -c "Add :UISupportedInterfaceOrientations array" "$PLIST"
$PB -c "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait" "$PLIST"

# Android: app label, and minimum Android 6.0 (the audio engine needs it).
perl -pi -e 's/android:label="cd_tuner_app"/android:label="CD Tuner"/' android/app/src/main/AndroidManifest.xml
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && perl -pi -e 's/minSdk(Version)?\s*=?\s*flutter\.minSdkVersion/minSdk = 23/' "$f"
done

flutter pub get
echo
echo "Done. Plug in your phone and run:  flutter run --release"
