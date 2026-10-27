# DashMax on the Garmin simulator

This is a **native Monkey C Connect IQ data field targeting Edge 840**, alongside the browser prototype. It uses custom drawing primitives and built-in device fonts. It is an explicitly labelled **simulator demo**: all ride values and wind are mocked. It does not read real sensors, fetch weather, or record an activity. Do not install this demo as a real ride dashboard.

**Validation status:** Monkey C source syntax and XML structure have been checked. The Garmin SDK download is blocked by the cloud network allowlist, so native compilation, simulator unit tests, device font fit, and runtime behavior have **not yet been verified**. The web prototype's passing tests are not Garmin simulator results. The commands below run those native checks on your computer.

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

Open **Settings → App Settings** in the simulator to change:

- Light/dark theme and metric/imperial units.
- Animated mock telemetry versus deterministic fixed readings.
- Oblique/head/tail/left/right wind, stale wind, or unavailable wind.
- Ordinary, 10-hour, 24-hour, 1000-km, and 1000-mile ride cases.
- Connected, missing, or stopped sensor states.

Apply the settings. The data field refreshes from the host activity's compute/update cadence rather than starting a background timer. There is no device touchscreen configuration UI in this data-field demo.

The wind dot marks the **source** of ambient wind relative to forward travel (the fixed up arrow). Positive along-track projection is headwind; negative is tailwind. Wind speed and component share the chosen speed units. Mock wind is 12 mph (19.3 km/h); the default oblique component is about 8 mph (12.9 km/h). The power graph has a fixed 0–450 W scale and 90-sample circular buffer. All averages are whole-ride mock values. Paused state freezes the mock clock; the demo does not model Garmin recording semantics.

## Run native unit tests

```sh
npm run garmin:test
```

This builds a separate `garmin/bin/DashMax-tests.prg` with the SDK's test flag and runs the two `(:test)` functions in Garmin's simulator. Check that the Garmin runner reports **two passed tests**: `testWindDirections` and `testLongRideFormatting`. An empty or skipped run is not a pass. Inspect compiler output, simulator console, and memory usage before calling this native target ready.

For manual acceptance checks, set animation off and test each ride length in both themes and both unit systems. Inspect the actual field rectangle at native resolution for clipped units, overlapping averages, and long elapsed times. Exercise all wind scenarios and missing/stopped sensor states. Re-enable animation and confirm the graph advances approximately once per second without errors. Built-in device fonts differ from the web font; final typography needs simulator/device review.

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

## Troubleshooting

- **SDK not found:** launch SDK Manager and select an installed SDK, or set `CIQ_SDK_HOME`.
- **Edge 840 package missing:** install that device in SDK Manager, then rerun doctor.
- **Java not found / incompatible Java:** install the Java version required by your SDK and reopen the terminal.
- **Simulator not ready:** launch it manually, inspect its error dialog/output, and rerun. Linux requires a desktop display and Garmin's supported GUI dependencies; a headless cloud shell alone cannot show an interactive window.
- **Small-layout message:** select the single-field/full-page data-field layout.
- **Compiler or runtime error:** retain the full compiler/simulator output. Native compilation is currently unverified; report the first error rather than treating a successful web build as evidence for this target.
