# Phase 5 — Mobile Polish & Release

**Goal:** the game feels good on a phone, runs smoothly on mid-range devices and can be published to the Google Play Store and Apple App Store.

---

## Touch controls

> 💡 **Why this needs real attention:** fighting games were designed for sticks and buttons. On glass there's no physical feedback, so motion inputs like `236` are hard. Successful mobile fighters solve this by adding *simple* control options alongside classic ones.

- [ ] Left side: a **floating virtual stick** (appears wherever the thumb lands) with 8-direction snapping and a dead zone
- [ ] Right side: 4 attack buttons (LP, RP, LK, RK) + a **block button**
- [ ] **Simple mode** (optional per player): a "Special" button + direction triggers a character's special moves. It is mapped via an extra `simple_command` field on `MoveDef`.
  > 💡 Adding this as a `MoveDef` field means every future character automatically supports simple mode.
- [ ] Customizable layout: move or resize buttons; saved to `user://settings.cfg`
- [ ] Haptic feedback on hit (`Input.vibrate_handheld`)
- [ ] Bluetooth controller support (already works through `input_router.gd`)
- [ ] Safe-area handling for notches and rounded corners

## Performance (target: steady 60 fps on a ~3-year-old mid-range phone)
- [ ] Use the **Mobile** renderer; bake lighting for the stage; at most 1 dynamic shadow
- [ ] Character LOD: about 15–25k triangles per fighter, 1–2 materials, 1k–2k textures (ETC2/ASTC compression)
- [ ] Profile with Godot's profiler on a real device; check sim time per tick and rollback cost
- [ ] Graphics settings: Low/Medium/High plus 30/60 fps rendering (**the sim always stays at 60**)
- [ ] Battery and heat: cap rendering FPS in menus

## Android
- [ ] Install Android Studio (SDK + JDK 17), then configure them in Godot's Editor Settings
- [ ] Create a release keystore (**back it up**: losing it means you can never update the app)
- [ ] Export template: arm64-v8a, AAB format for the Play Store
- [ ] Test on 2–3 devices via one-click deploy (USB debugging)
- [ ] Play Console: store listing, content rating, privacy policy (needed because of online play), internal testing → closed beta → production

## iOS
- [ ] Requires a Mac + Xcode + an Apple Developer account ($99/yr)
- [ ] Export the Xcode project from Godot, then set the signing team and bundle id
- [ ] TestFlight beta → App Store review
- [ ] App Tracking/privacy labels (Nakama device ID counts as an identifier)

## Release checklist
- [ ] App icon, splash screen, store screenshots, trailer
- [ ] Settings: audio, controls, graphics, language
- [ ] Crash/error logging (e.g. Sentry Godot SDK)
- [ ] `game_version` bumped, and the data hash checked against the server's allowed versions
- [ ] Privacy policy + terms hosted online

## Done when
- A closed beta build is live on both stores (internal or TestFlight). Testers can play vs CPU and online with comfortable touch controls at 60 fps.
