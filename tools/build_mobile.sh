#!/usr/bin/env bash
# Builds the mobile versions of Rann.
#
#   tools/build_mobile.sh android-debug    → build/android/rann-debug.apk (install with adb)
#   tools/build_mobile.sh android-release  → build/android/rann-release.aab (upload to Play Console)
#   tools/build_mobile.sh ios              → build/ios/Rann.xcodeproj (open in Xcode, then Archive)
#
# The release build needs your signing key in environment variables, so the
# password is never written into the project (see plans/05-phase-mobile-release.md):
#   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/rann-release.keystore
#   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=rann
#   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='…'
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  android-debug)
    mkdir -p build/android
    godot --headless --path . --export-debug "Android Debug" build/android/rann-debug.apk
    echo "Install on a phone (USB debugging on): adb install -r build/android/rann-debug.apk"
    ;;
  android-release)
    for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
      if [ -z "${!v:-}" ]; then echo "Missing $v (see the comment at the top of this script)"; exit 1; fi
    done
    mkdir -p build/android
    # --install-android-build-template sets up the Gradle project on first use.
    godot --headless --path . --install-android-build-template --export-release "Android Release" build/android/rann-release.aab
    ;;
  ios)
    mkdir -p build/ios
    godot --headless --path . --export-release "iOS" build/ios/Rann.xcodeproj
    echo "Open build/ios/Rann.xcodeproj in Xcode, pick your team under Signing, then Product → Archive."
    ;;
  *)
    sed -n '2,12p' "$0"; exit 1 ;;
esac
