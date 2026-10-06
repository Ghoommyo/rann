# Phase 5 — Mobile Polish & Release

**Goal:** the game feels good on a phone, runs smoothly on mid-range devices and can be published to the Google Play Store and Apple App Store.

---

## Touch controls

> 💡 **Why this needs real attention:** fighting games were designed for sticks and buttons. On glass there's no physical feedback, so motion inputs like `236` are hard. Successful mobile fighters solve this by adding *simple* control options alongside classic ones.

- [x] Left side: a **floating virtual stick** (appears wherever the thumb lands) with 8-direction snapping and a dead zone
- [x] Right side: 4 attack buttons (LP, RP, LK, RK) + a **block button**
- [x] **Simple mode** (optional per player): a "Special" button + direction triggers a character's special moves. It is mapped via an extra `simple_command` field on `MoveDef`.
  > 💡 Adding this as a `MoveDef` field means every future character automatically supports simple mode.
- [x] Customizable layout: move or resize buttons; saved to `user://settings.cfg`
- [x] Haptic feedback on hit (`Input.vibrate_handheld`)
- [x] Bluetooth controller support (already works through `input_router.gd`)
- [x] Safe-area handling for notches and rounded corners

## Performance (target: steady 60 fps on a ~3-year-old mid-range phone)
- [x] Use the **Mobile** renderer; bake lighting for the stage; at most 1 dynamic shadow
- [ ] Character LOD: about 15–25k triangles per fighter, 1–2 materials, 1k–2k textures (ETC2/ASTC compression)
- [ ] Profile with Godot's profiler on a real device; check sim time per tick and rollback cost
- [x] Graphics settings: Low/Medium/High plus 30/60 fps rendering (**the sim always stays at 60**)
- [x] Battery and heat: cap rendering FPS in menus

## Android
- [x] Install Android Studio (SDK + JDK 17), then configure them in Godot's Editor Settings
- [ ] Create a release keystore (**back it up**: losing it means you can never update the app)
- [x] Export template: arm64-v8a, AAB format for the Play Store
- [ ] Test on 2–3 devices via one-click deploy (USB debugging)
- [ ] Play Console: store listing, content rating, privacy policy (needed because of online play), internal testing → closed beta → production

## iOS
- [ ] Requires a Mac + Xcode + an Apple Developer account ($99/yr)
- [ ] Export the Xcode project from Godot, then set the signing team and bundle id
- [ ] TestFlight beta → App Store review
- [ ] App Tracking/privacy labels (Nakama device ID counts as an identifier)

## Release checklist
- [ ] App icon, splash screen, store screenshots, trailer
- [x] Settings: audio, controls, graphics (language selection not done yet)
- [ ] Crash/error logging (e.g. Sentry Godot SDK)
- [x] `game_version` bumped, and the data hash checked against the server's allowed versions
- [ ] Privacy policy + terms hosted online

## Done when
- A closed beta build is live on both stores (internal or TestFlight). Testers can play vs CPU and online with comfortable touch controls at 60 fps.

---

## Status: 🟡 game side done (2026-10-06); signing, store and iOS steps are yours
119 tests pass. The debug APK (**37 MB**, arm64, `com.rann.game` 0.5.0) builds, installs and runs on an Android emulator (Pixel 9a, Android 16): menus, character select, a fight with the 3D models, and touch input (a tap on LP starts Kael's jab).

**What was built**
- **Touch controls v2** (`ui/touch_controls.gd`): a floating stick, LP / RP / LK / RK, **SP** (special) and **BLOCK** (holds back, or down-back with the stick down). Quick taps are latched so none get lost. Safe-area aware.
- **Simple controls:** `MoveDef.simple_command` + the SP button (`SP`, `6+SP`, `2+SP`), ranked separately from classic inputs. Kael: SP = Dashing Punch, 6+SP = Uppercut, 2+SP = Rage Burst. Mira: SP = stance switch, 6+SP = Rising Crane (Crane), 2+SP = Tail Sweep. Keyboard `L`, gamepad R1.
- **Settings** (`game/settings.gd`, saved to `user://settings.cfg`): volume, graphics Low/Medium/High (render scale, MSAA, shadows, glow, fog, lights), 30/60 fps drawing (the sim stays at 60), vibration, touch controls Auto/On/Off, button size, and a **drag-to-edit touch layout** screen.
- Vibration on hits and KOs. FPS and frame time in the F3 panel.
- **Packaging:** `export_presets.cfg` (Android Debug APK, Android Release AAB via Gradle, iOS), app icon, sensor-landscape orientation, ETC2/ASTC texture compression, "expand" aspect mode (no black bars on 20:9 phones), Kael's 4K textures capped to 1024 (the APK went from 74 MB to 37 MB). Permissions: INTERNET, NETWORK_STATE, WIFI_STATE, VIBRATE.
- `tools/build_mobile.sh` (android-debug / android-release / ios), `docs/privacy-policy.md`, `docs/store-listing.md`.

**Known issues**
- The emulator can't show the Vulkan (Mobile) renderer when it runs without a window ("Couldn't present to Vulkan queue"). The game was checked there with the OpenGL renderer in a throwaway test build. **Test on a real phone** to see real performance (the emulator's 7 fps is software rendering on the CPU).
- The **AAB build couldn't download Gradle** from inside my sandboxed terminal. Run it yourself (below); the Gradle project is already installed in `android/`.

## Your steps
### 1. Create the release key (once, then back it up)
```bash
mkdir -p ~/keys && keytool -genkeypair -v -keystore ~/keys/rann-release.keystore -alias rann \
  -keyalg RSA -keysize 2048 -validity 10000
```
> ⚠️ **Back up `~/keys/rann-release.keystore` and its password somewhere safe** (a password manager plus a second copy). If it's lost, the Play Store app can **never be updated** again. It's git-ignored and must never be committed.

### 2. Build the Play Store bundle
```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/rann-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=rann
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='your password'
tools/build_mobile.sh android-release      # → build/android/rann-release.aab
```
Then upload it in Play Console: Internal testing → closed testing → production.

### 3. Test on your phone
Turn on Developer options and USB debugging, plug the phone in, then run `tools/build_mobile.sh android-debug && adb install -r build/android/rann-debug.apk`.

### 4. iOS
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # use the full Xcode
```
Sign in to Xcode with your Apple ID (Settings → Accounts). Put your Team ID in `export_presets.cfg` (`application/app_store_team_id`), then run `tools/build_mobile.sh ios` and open the project in Xcode → Archive → TestFlight. You need an Apple Developer account ($99/year) to publish.

### 5. Store pages
Fill in `docs/store-listing.md`, and host `docs/privacy-policy.md` at a public URL with your contact email added.
