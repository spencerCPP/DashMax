# DashMax on the Garmin simulator

This is a **native Monkey C Connect IQ data field targeting Edge 840**, alongside the browser prototype. It uses custom drawing primitives and built-in device fonts. Choose between mock telemetry and host activity data, including FIT playback in Garmin's simulator. It does not fetch weather or record activities itself. This is a development test field, not a validated production ride dashboard.

**Validation status:** SDK 9.3.0 compiled the original native target successfully on macOS. A reported runtime crash from unsupported `Math.abs` calls was fixed. FIT playback has since been exercised on macOS. The new heading display has passed source syntax checks but has **not yet been compiled or run in Garmin's simulator**: cloud SDK downloads remain blocked. Run the local native tests and playback checks below; web test results are not native simulator results.

## One-time installation

1. Install [Garmin Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/) for your OS. Open it, follow Garmin's licence/sign-in prompts if shown, install a current stable SDK, and make it the active SDK.
2. In SDK Manager, install the **Edge 840** device package. The SDK alone is insufficient.
3. Install a Java runtime supported by your selected SDK. Java must be available as `java` in a new terminal. Check the SDK release notes for its required Java version.
4. Install Node.js 24 LTS (or use the Node 24 runtime already used for the web project). Git and Node must be on PATH. These native helper commands use only Node built-ins; `npm ci` is not required for the Garmin target.
5. Get this version of DashMax on your computer and open a terminal at its repository root. If you already have a checkout, update it once these changes are pushed; otherwise use `git clone https://github.com/spencerCPP/DashMax.git` and `cd DashMax`.

## Build and launch

The following commands work from PowerShell, macOS Terminal, and Linux shells:

```sh
npm run garmin:doctor
npm run garmin:build
npm run garmin:sim
```

- `doctor` checks Java, the active SDK, and the installed Edge 840 device package.
- `build` creates `garmin/bin/DashMax.prg`. On first build it generates a local RSA-4096 PKCS#8 DER development signing key at `garmin/.keys/developer_key.der`. Keys and binaries are ignored by Git. Keep your own release signing key separate; this is only a development key.
- `sim` rebuilds, opens Garmin's actual simulator, waits for its protocol readiness, and loads the program as an Edge 840 data field. If automatic startup fails, open the simulator from SDK Manager and rerun `npm run garmin:sim`.

Select a **single-field/full-page layout** in the simulator's **Data Fields** menu. This is necessary: Garmin controls the available data-field rectangle, so it can be smaller than the entire 246 × 322 physical display. DashMax adapts to that rectangle and asks for a full-page layout when it is too small. This is not a standalone replacement for Garmin's activity UI.

For FIT playback, use `npm run garmin:fit` instead of `garmin:sim`. This builds a separate `DashMax-fit.prg` with activity-data mode forced on; it does not require any application-settings menu or editor. It does not change tracked source or your saved app properties. The generated build copy is ignored under `garmin/bin/fit-project`.

Other demo options are declared in `resources/settings/properties.xml` (mock animation and ride/sensor scenarios). The simulator's **Settings** menu controls the simulated device; it is not an application-properties editor in SDK 9.3. For a simple local demo configuration, stop the app, edit the defaults in that XML file, and rebuild with `garmin:sim`. Existing stored application properties can override changed defaults; do not rely on this method to force FIT playback. Use `garmin:fit` for that.

**Native theme follows the host data-field background.** In the simulator, use **Data Fields → Background Color → White / Black**. DashMax reads the inherited `WatchUi.DataField.getBackgroundColor()` on every redraw, clears to that actual host color, and selects contrasting text/divider/graph colors. It no longer reads a separate `Dark` app property; previously saved values are ignored. This is the data-field background preference, not a direct query of device Night Mode. The browser prototype keeps its independent light/dark demo switch. After updating, verify both White and Black while FIT playback is running; native theme switching still requires local simulator validation.

**Native units follow Garmin automatically.** Change **Settings → Units Display → Metric / Statute** in the simulator. DashMax reads `System.getDeviceSettings().distanceUnits` on each redraw: Metric shows km and km/h; Statute shows mi and mph. Current/average speed and distance use that selection. Power, heart rate, cadence, and elapsed time are unchanged. There is no separate native imperial toggle; old stored app unit preferences are ignored. The browser prototype retains its own demo unit controls.

The data field refreshes from the host activity's compute/update cadence rather than starting a background timer. There is no device touchscreen configuration UI in this test field.

The footer now shows **HEADING**: a north-up travel arrow, compass direction, and degrees clockwise from north. In activity mode it uses `Activity.Info.currentHeading` (radians), converted to degrees. When GPS course is missing or current speed is below **1 m/s**, it shows `NO COURSE` instead of a potentially unstable direction. It is not a stationary magnetic compass or a navigation cue. Mock mode points north and hides heading when paused. Wind display, wind calculations, and wind settings have been removed.

The power graph has a fixed 0–450 W scale and a 90-sample circular buffer. Mock averages are whole-ride values; activity mode uses host-supplied averages. Paused mock state freezes the mock clock.

## Replay a real activity FIT file on macOS

1. Pull the latest source and run `npm run garmin:fit` from the repository root. The terminal must report **Data source: ACTIVITY / FIT PLAYBACK (forced)**.
2. Select the single-field/full-page layout from **Data Fields**.
3. No application-settings step is needed. Mock ride-length, sensor-state, and animation settings are ignored in this build. Until activity data arrives, absent metrics display `--`.
4. In the Garmin simulator, choose **Simulation → FIT Data → Playback File…** and select a recorded cycling activity `.fit` file from your Mac. Start/resume playback using the FIT playback controls. Start the simulated activity timer if needed by your SDK's simulator.
5. Confirm the values change with the recording. Use the simulator's FIT playback controls to stop/restart the recording. A backwards activity clock or a gap exceeding three seconds resets the power window and graph history.

Use an **activity recording**, not a route/course or structured-workout FIT file. The file stays on your computer; there is no web upload or server processing. Export the original activity from Garmin Connect and unzip it if the export arrives as a ZIP. Missing power/HR/cadence channels cannot be reconstructed and display `--`; zero cadence/power is kept as a real zero. Simulator sample-rate and channel support depend on the FIT file and SDK.

### Cadence doubled during simulator playback

A decoded user-provided cycling recording confirmed that the simulator supplied doubled cadence in the reported run. At the matching sample, FIT cadence is **86 rpm**, HR **148 bpm**, speed **23.2 km/h**, distance **111.02 m**, and three-second power **59 W**; the screenshot matches those channels but displays **172 rpm**. The recording passes FIT integrity checks and has a maximum cadence of **129 rpm**. DashMax's ordinary activity adapter passes cadence through unchanged. This establishes a playback discrepancy, but not its exact cause inside the simulator; activity/sport interpretation remains a possibility. Single-sided power measurement does not require doubling cycling cadence.

For that observed simulator behavior, launch with an explicit correction:

```sh
npm run garmin:fit -- --cadence-divisor=2
```

The terminal must report **Replay cadence divisor: 2**. This divides only cadence in the generated FIT build; it leaves the FIT file and power unchanged. Use it only when a recording comparison confirms the simulator is doubling cadence. Normal `npm run garmin:fit` uses divisor **1** and preserves the supplied value, including high cadence readings. If simulator settings or a future SDK resolve the doubling, return to divisor 1. Native regression tests cover unchanged normal/high cadence, the explicit 172→86 and 192→96 corrections, zero, and missing values. Native execution of this new correction still requires local SDK validation.

Current power is a sample mean of available readings in the trailing three activity seconds (a shorter window during startup); samples with missing current power display `--` and create a gap. The graph contains the last 90 accepted updates, approximately 90 seconds at normal 1 Hz playback; it uses a fixed 0–450 W range and clips higher graph points without clamping the hero number. Speed is converted from Garmin's m/s to km/h or mph, distance from metres to km or mi, and elapsed time from milliseconds. Whole-activity averages come only from Garmin's `Activity.Info` average fields, not lap fields or hardcoded demo values. They may be unavailable or reflect the simulator's accumulated playback rather than the FIT file's saved session summary. Elapsed time/distance are the simulated host activity's values, which can differ from the FIT summary after pauses or seeking.

FIT playback verifies the activity data path and rendering, not real-device sensor integration or recording behavior. Heading availability depends on whether the simulator supplies GPS course from the replay. Missing course stays unavailable; the field does not invent a heading from wind or other sensors.

## Run native unit tests

```sh
npm run garmin:test
```

This builds a separate `garmin/bin/DashMax-tests.prg` with the SDK's test flag and runs the seven `(:test)` functions in Garmin's simulator. Check that the Garmin runner reports **seven passed tests**: heading math, formatting, activity unit conversion/missing values, three-second power smoothing, playback seek/gap resets, explicit replay cadence correction, and GPS heading availability. An empty or skipped run is not a pass. Inspect compiler output, simulator console, and memory usage before calling this native target ready.

For manual acceptance checks, set animation off and test each ride length with both host background colors and both unit systems. Inspect the actual field rectangle at native resolution for clipped units, overlapping averages, and long elapsed times. Exercise cardinal headings and missing/stopped sensor states. Re-enable animation and confirm the graph advances approximately once per second without errors. Built-in device fonts differ from the web font; final typography needs simulator/device review.

## SDK discovery and optional overrides

The helper reads Garmin's `current-sdk.cfg` from the standard ConnectIQ directory:

| OS | ConnectIQ directory |
| --- | --- |
| Windows | `%APPDATA%\Garmin\ConnectIQ` |
| macOS | `~/Library/Application Support/Garmin/ConnectIQ` |
| Linux | `~/.Garmin/ConnectIQ` |

If SDK Manager did not select an active SDK, point `CIQ_SDK_HOME` at the extracted SDK directory containing `bin/monkeybrains.jar`:

PowerShell:

```powershell
$env:CIQ_SDK_HOME = 'C:\path\to\connectiq-sdk'
npm run garmin:doctor
```

macOS/Linux:

```sh
export CIQ_SDK_HOME='/path/to/connectiq-sdk'
npm run garmin:doctor
```

Optional `CIQ_DEVELOPER_KEY` points to an existing local DER signing key instead of generating one. Never commit that key. Device packages must still be installed by Garmin SDK Manager in its standard ConnectIQ directory. Paths containing shell metacharacters are rejected by the Windows batch launcher; use a plain directory name in that case.

## VS Code alternative

Install Garmin's **Monkey C** extension and open the `garmin` directory as your workspace (it contains `monkey.jungle`). Select Edge 840 as the target, configure your development key through the extension, and use the extension's build/run commands. This uses the same sources and manifest as the npm commands.

## Simulator console output across rebuilds

The launcher now sends the simulator process's stdout/stderr to the ignored file `garmin/bin/simulator.log` and streams new bytes into each `garmin:sim`, `garmin:fit`, or `garmin:test` run. The simulator can remain open between builds; output no longer depends on which Terminal session originally started it. `monkeydo` output is also inherited normally.

**Quit the simulator once after updating to this launcher**, then start it through an npm Garmin command. An already-running simulator retains its original output descriptors; they cannot be reattached retroactively. A simulator opened independently through SDK Manager may also need to be closed once so the launcher can start it with log capture.

For a separate persistent console window on macOS/Linux:

```sh
tail -f garmin/bin/simulator.log
```

Add `System.println(...)` to `garmin/source/`, then rebuild. FIT builds overwrite the generated copy under `garmin/bin/fit-project`, so changes made directly in that generated directory are temporary. The log is appended across runs; the CLI streams only new output. The file-following/reconnection tests pass under Node, but simulator capture still needs local macOS validation.

## Troubleshooting

- **SDK not found:** launch SDK Manager and select an installed SDK, or set `CIQ_SDK_HOME`.
- **Edge 840 package missing:** install that device in SDK Manager, then rerun doctor.
- **Java not found / incompatible Java:** install the Java version required by your SDK and reopen the terminal.
- **Simulator not ready:** launch it manually, inspect its error dialog/output, and rerun. Linux requires a desktop display and Garmin's supported GUI dependencies; a headless cloud shell alone cannot show an interactive window.
- **Small-layout message:** select the single-field/full-page data-field layout.
- **Compiler or runtime error:** retain the full compiler/simulator output. Native compilation is currently unverified; report the first error rather than treating a successful web build as evidence for this target.
