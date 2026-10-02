# Release candidate 1.0.0 (20) — 2 October 2026

New identity: `com.oanarinaldi.afterlight`, App Store Connect `6818519420`, Afterlight: Racing Festival. The distribution archive succeeded and Apple accepted the upload at 15:48 EEST. Store submission status is tracked in SubmissionStrategy.md.

- Final physical iPhone 17 Pro Max sweep passed all twenty route-opening render checks, each at least 30 fps, with zero failures in 198.746 seconds. This is a short opening-segment sample per route, not a sustained full-lap thermal benchmark. Result: `/tmp/AfterlightPhone20/Logs/Test/Test-Afterlight-2026.10.02_15-43-41-+0300.xcresult`; log: `/tmp/afterlight20-phone-final-routes.log`.
- Physical repeated nitro holds passed: elapsed race time advanced from 1.01674 to 6.36050 seconds, 237 boost samples, maximum simulation callback interval 54.45 ms. Callback timing does not measure GPU presentation. The test now waits for the actual countdown to finish instead of assuming cold startup always takes three seconds. Earlier build 19 failures remain recorded in the local logs.
- Render cost was reduced to 2x scene scale and 2x MSAA while SwiftUI remains at native display resolution. The hidden showroom renderer stops while a race is presented or the application is inactive. Earlier build 20 samples failed routes 0 and 17 before this showroom fix; the final sweep above passed both.
- Final simulator run passed 26 unit/art checks and the iPad layout journey (`/tmp/afterlight20-tablet-final.log`). Checks include all-route road clearance, models/colliders, progression, steering, nitro, closed roofs, finite terrain normals and foliage alpha cutouts.
- Complete simulator race/results/next-event flow and repeated nitro input passed (`/tmp/afterlight20-journey.log`). That run preceded the final hidden-showroom lifecycle adjustment; the final physical sweep and iPad/unit invocation include it.
- Six iPhone and five iPad screenshots in `screenshots-build20/` are actual native captures, normalized for image orientation only. Circuit thumbnails are native scene renders; the fictional crew illustration is generated artwork.
- Build 20 is installed on the phone. Relaunch after the completed sweep returned the iOS Locked error; the user can open Afterlight directly after unlocking.
- Dedicated privacy policy published at https://oanarinaldi.com/afterlightprivacy.html; website commits `81d1ce5` and `25337a3`. Apple Data Not Collected label published after the owner's explicit approval. No accounts, ads, analytics, purchases or network game services were added.

Licensed source art and generated decryption keys remain excluded from Git. The archive contains the local licensed runtime art; public source builds use credited fallback assets. Remaining visual limitations are documented in VisualReview.md.

---

# Development build 18 — terrain, roofs and vegetation

2 October 2026. Version 2.0.0 (18) compiled and installed on Oana’s iPhone. The subsequent launch request returned the iOS `Locked` error. The physical route sweep waited for unlock and was canceled without running; build 18 physical launch and performance are unverified. The installed app can be opened directly. Existing saves are preserved; review launches use isolated fixtures.

Completed checks:

- Final simulator invocation passed all 24 unit tests and the all-twenty-route opening-segment review. Each short simulator render sample met the 30 fps threshold. This does not establish sustained physical-device performance or full-lap art coverage.
- The two new tests validate closed roof topology/outward winding and terrain texture resolution/finite surface normals. Existing collision, progression, roster, steering geometry, landmark and complete-circuit scenery-clearance tests also passed.
- The full race/results/next-event journey passed in a separate build 18 invocation before the final canopy/lighting asset corrections. Gameplay code was unchanged by those corrections.
- Device build-for-testing completed successfully. Source asset hashes match the simulator app’s bundled final fir; vendor download checksums and final model hashes are recorded in environment-build18-assets.json.
- Representative actual native simulator captures are in screenshots-build18/. The separate generated coastal concept is development reference only.

Final simulator log: `/tmp/afterlight18-final-routes.log`; result: `/tmp/AfterlightArt8/Logs/Test/Test-Afterlight-2026.10.02_15-04-10-+0300.xcresult`. Earlier complete journey: `/tmp/afterlight18-final-check.log`. Device build: `/tmp/afterlight18-phone-final-build.log`; blocked physical sweep: `/tmp/afterlight18-phone-routes.log`.

Art limitations remain documented in VisualReview.md and ArtDirection.md. App Store submission remains pending refinement; no upload or identifier change was made. No new collection or network services were introduced; the existing privacy policy remains applicable. SubmissionStrategy.md records the recommendation to address the original rejection transparently using the current app record.

---

# Development build 17 — nitro and rival corrections

2 October 2026. Version 2.0.0 (17) compiled, installed and launched on Oana’s iPhone. The physical-device repeated-nitro-hold test passed after unlock. Existing saves are preserved; UI reviews use an isolated fixture.

The new regressions reproduced the old 8-degree lens snap, 1.2-metre chase-camera jump, and repeated boost pulses near an empty tank. Build 17 eases the lens and chase distance with a time-based blend, latches exhausted nitro until release, and replaces the default-mode Timer/Task queue with a main-run-loop CADisplayLink registered in common modes. Scene transforms are applied without implicit animations. Apple documents display-link scheduling and run-loop modes in [CADisplayLink](https://developer.apple.com/documentation/quartzcore/cadisplaylink) and [add(to:forMode:)](https://developer.apple.com/documentation/quartzcore/cadisplaylink/add(to:formode:)). The physical-device timing test also passed; subjective visual quality still needs player review.

Rivals are selected from three different body families, excluding the player’s family. The later three garage entries are treated as one family so roof/wing variants cannot duplicate the player. Model selection is shared with the renderer. All cars retain their existing body colliders and rotating wheels.

Completed validation:

- 22 unit tests passed, including smooth nitro activation/release, exhausted-tank hold/repress, all six player cars across all twenty rival rosters, collisions, progression and scenery clearance.
- The UI nitro case performed repeated 0.5-, 0.7- and 3-second holds with the full rival grid. It recorded 250 simulation callbacks during holds, with a maximum timestamp interval of 16.67 ms. Race elapsed time advanced from 2.367 to 7.467 seconds across the interaction sequence. This measures the simulation clock in the simulator, not GPU performance on the phone.
- On the physical iPhone, repeated nitro holds recorded 252 simulation callbacks with a maximum timestamp gap of 16.67 ms; elapsed race time advanced from 1.999 to 7.266 seconds. The UI test passed with no failures (`/tmp/afterlight17-phone-nitro.log`). This measures simulation callback timing, not GPU frame delivery. Xcode reported a separate post-test diagnostics-collection warning.
- The full rival-grid simulator render sample recorded 58.5 fps. Actual steering buttons passed in both landscape orientations.
- The complete race/results/next-event journey passed in a separate completed invocation after the simulation clock change.
- `/tmp/afterlight17-check.log` and `/tmp/afterlight17-journey.log` both ended with TEST SUCCEEDED. Before-fix reproduction: `/tmp/afterlight17-nitro-before.log`. Device build/install: `/tmp/afterlight17-phone.log`, `/tmp/afterlight17-phone-tests-build.log`, `/tmp/afterlight17-install.log`.

The physical-device twenty-route showcase completed all twenty launches and screenshot captures. Eighteen short render samples met the 30 fps threshold; Palm Coast (route 0) measured 28.4 fps and Metropolis (route 10) measured 29.5 fps, so the performance test failed two assertions. These routes need further profiling; this was a short opening-segment sweep, not full-lap validation. Log: `/tmp/afterlight17-phone-routes.log`. Result: `/tmp/AfterlightPhone8/Logs/Test/Test-Afterlight-2026.10.02_14-34-02-+0300.xcresult`. The app was relaunched without review arguments after the showcase.

Native render and timing evidence: `release/screenshots-build17/`. No new collection or external services; existing privacy policy remains applicable. App Store submission stays on hold for broader product/art review.

---

# Development build 16 — 2 October 2026

Version 2.0.0 (16) installed on Oana’s iPhone. Automated launch remained blocked by the device lock, including the retry after the user reported unlocking. Users can open the installed game directly. No physical-device frame-rate claim is made.

Final validation completed with TEST SUCCEEDED: 19 unit tests, the refined canyon visual case and complete race-to-results/next-event UI journey (`/tmp/afterlight16-final.log`). The separate twenty-route visual sweep also completed successfully, with each route meeting the simulator 30 fps minimum (`/tmp/afterlight16-verified.log`). Actual LEFT/RIGHT touch input in both landscape orientations passed in build 15 and that correction is included in build 16.

App Store submission remains held for further visual refinement and device playtesting. Privacy policy remains applicable: all changes are local/offline. Details and representative captures are recorded in VisualReview.md.

---

# Steering correction — development build 15

The new camera-space regression reproduced reversed steering in build 14: both the car’s displacement and yaw opposed the labeled input. Corrected the conversion between screen-oriented steering and the authored road normal. The buttons retain LEFT = -1 and RIGHT = +1; the physics input now respects the rear-facing camera’s horizontal axis.

All 18 unit tests passed after correction. The final targeted invocation completed with TEST SUCCEEDED, verifying camera-space displacement/yaw and the actual LEFT/RIGHT buttons in both landscape orientations. The first UI probe returned stale telemetry; observing the engine in SceneSurface fixed the probe, and all four touch cases then passed. Evidence: `/tmp/afterlight15-controls-before.log`, `/tmp/afterlight15-controls.log`, `/tmp/afterlight15-controls-final.log`.

Device build 15 compiled and installed. Initial launch and the retry were both blocked by iOS reporting the device locked. The user can launch the installed build directly; automated physical launch was not verified for build 15.

# Development build 14 validation — 2 October 2026

TurboRacer: Afterlight 2.0.0 (14). Existing App Store app 6478083613.

- Final iPhone simulator run completed successfully: 17 unit tests plus all-twenty-route navigation and six-car/four-environment visual UI cases. `/tmp/afterlight14-verified.log`.
- Race/results/next-event and rival-grid UI cases passed in the earlier art run; see VisualReview.md for the test-fixture failure and subsequent successful rerun. Separate iPad layout run completed successfully: `/tmp/afterlight14-tablet.log`.
- Four environment snapshots recorded 60 fps; rival-grid sample recorded 56.7 fps. These are simulator samples, not sustained physical-device measurements.
- Device build succeeded. Build 14 installed on Oana’s iPhone and devicectl confirmed launch. Existing progress was preserved.
- Actual native simulator captures are in `screenshots-build14/`. Further scene polish and physical-device playtesting remain necessary.
- No new data collection or network services. Privacy website commit 32802dd remains applicable.
- Build 14 has **not** been uploaded or submitted to App Store Connect. Store submission remains held for product and visual refinement.

Full evidence and remaining art limitations: [VisualReview.md](VisualReview.md).

<details>
<summary>Historical build 5 release validation</summary>

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

</details>
