# Release validation — 2 October 2026

TurboRacer: Afterlight 2.0.0 (5), existing App Store app 6478083613.

- iPhone simulator: seven unit tests and complete UI racing journey passed; `/tmp/AfterlightFinal.xcresult` completed successfully.
- iPad 13-inch simulator: home, garage, journal, map, driving controls and pause journey passed; `/tmp/AfterlightTablet.xcresult` completed successfully.
- Final steering and palm-normal adjustments: all seven unit tests and UI journey reported zero failures in `/tmp/afterlight-release-check.log`; the Xcode runner stalled while finalizing its result bundle. Do not count that invocation as a completed xcodebuild command.
- Distribution archive succeeded. The archive's actual Info.plist was checked: version 2.0.0, build 5. Automatic distribution signing works.
- Debug device build succeeded and was installed on the connected iPhone 17 Pro Max. Launch was blocked by the phone lock; physical-device play/performance still requires user verification.
- Screenshots in this folder are actual simulator captures, not promotional mockups.
- Privacy policy website change 32802dd pushed; deployment succeeded and live policy verified.

## Store completion

Build upload and Apple processing must finish before selecting build 5 for review. Replace the legacy insect-game screenshots in every populated device size with the included Afterlight captures. Permanent removal of existing screenshots awaits user confirmation under the computer-use policy. Submission is not complete until App Store Connect confirms it.

## Practical limits

This is an original playable native arcade game, not a licensed-car simulator. Device performance and long-session playtesting remain important before broad release. Apple decides acceptance under its current review guidelines.
