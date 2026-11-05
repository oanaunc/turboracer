# Afterlight for Android

Android 10 and later, target API 36, `com.oanarinaldi.afterlight`, version 1.0.0 (1). The Apple build in `Afterlight/` is the source for content, geometry, car definitions, route layouts, progression and driving rules.

The app runs a bundled WebGL renderer and HTML interface inside a restricted Android WebView. It requires no network permission, account, ads, purchases or analytics. Android provides immersive landscape display, local saving, haptics, tilt controls, lifecycle pausing and system Back navigation. Twelve cars, twenty circuits, eighty campaign events, all six race modes, story/notebook chapters, daily challenges, upgrades, stunts and collectible rewards are included.

The Android renderer consumes the original Apple scene geometry, textures, transforms, lighting definitions and collision dimensions. Menus follow the Apple composition, dimensions and colors. Roboto Condensed and original SVG controls replace Apple's licensed system font and symbols. SceneKit and WebGL lighting, post effects, procedural material shaders and system dialogs are separate implementations; pixel identity must not be inferred from sharing scene assets.

## Build inputs

Licensed model packs, generated keys and Android scene packages stay outside Git. A public checkout requires the owner's legitimate private Apple art inputs to reproduce the licensed release. They are not source assets for redistribution.

1. Install the Android Studio JDK, Android API 36 SDK, Node, Python and Xcode/XcodeGen.
2. Run `python3 android/scripts/sync-ios-content.py` after changing the Swift catalogue or story.
3. Run `Afterlight/Tools/generate_project.sh`.
4. Export the actual scenes using an existing iOS simulator:

```sh
TEST_RUNNER_AFTERLIGHT_EXPORT_ANDROID=1 xcodebuild \
  -project Afterlight/Afterlight.xcodeproj -scheme Afterlight \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UUID' \
  -only-testing:AfterlightTests/AndroidExportTests \
  test CODE_SIGNING_ALLOWED=NO
```

The export prints `ANDROID_SCENE_EXPORT=.../Documents/AndroidScenes`. Copy that directory privately to `build/android-scenes`. The opt-in exporter temporarily retains the original hierarchy instead of SceneKit's GPU-only flattened meshes; it restores the original method when finished. It never changes the shipping application or player saves.

5. In a Python environment with Pillow and cryptography, run:

```sh
python android/scripts/package-art.py build/android-scenes
```

Packaging compresses and AES-GCM encrypts private meshes, textures and scene definitions. The private packaging key lives in `~/.local/share/afterlight/android-art/`. Images are capped at 2048px to bound mobile GPU memory. Encryption discourages casual extraction and does not change license obligations or claim tamper-proof protection.

The `festival_art` module uses install-time Play Asset Delivery. All art is installed with the game and available offline at first launch. The debug APK includes these assets directly for local tests; the production AAB supplies them as an install-time split.

```sh
node --test android/tests/engine.test.mjs
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
ANDROID_HOME="$HOME/Library/Android/sdk" \
android/gradlew -p android :app:assembleDebug :app:assembleDebugAndroidTest
```

Run the instrumented `JourneyTest` on a dedicated emulator. It covers the tutorial, real held touch controls, pause/resume, results/rewards, story and world content, four rendered districts and save restoration. Debug-only review fixtures are unavailable in production. UI tests write actual device captures under the app's external `files/qa/` folder.

## Signing and release

Run `python3 android/scripts/create-upload-key.py` only once for this app. The unique key and signing JSON live in `~/.local/share/afterlight/android-upload/`. Preserve and privately back up that directory. The build script reads credentials without logging them.

```sh
python3 android/scripts/build-release.py
```

This checks source content, gameplay tests, complete scene packaging, release signing, AAB compilation and release lint. Artifacts and SHA-256 evidence go to `release/google-play/`. Install the production bundle using Google's bundletool, including its install-time asset split; the base APK alone does not contain the scenery.

For a local browser preview of private assets, run `node android/scripts/preview.mjs` and open http://127.0.0.1:8078. The development server binds only to localhost. It serves art in place, keeping plaintext out of the bundled web source and Git.
