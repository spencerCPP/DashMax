# DashMax

Interactive browser concept for a Garmin Edge 840 cycling dashboard. The screen is exactly **246 × 322 logical pixels**; preview zoom scales the same geometry. No hardware, account, weather API, or secrets are needed. Fonts are bundled locally.

## Develop

Node 24 (Node >=22.12 also supported).

```sh
npm ci
npm run dev
```

In the cloud environment use `export npm_config_cache=/workspace/.npm-cache` if the default cache is unwritable. `npm run build` type-checks and produces `dist/`. `npm test` checks heading conversion and unit/time formatting. `npm run preview` serves the production build.

## Demo

Light theme and metric units are the defaults. Start with deterministic telemetry, or play the repeatable 1 Hz power sequence. The trace retains 90 samples on a fixed 0–450 W scale. Averages are whole-ride mock values, not computed lap averages. Current power represents mock 3-second-smoothed readings. Reset restores the original mock state.

The footer shows rider heading: a north-up arrow, compass direction, and bearing in degrees. Browser controls supply a mock GPS course; missing course and paused activity show an unavailable heading. The native field reads GPS travel course and hides heading below 1 m/s, where course can be unreliable. This is travel direction, not a stationary compass or navigation instruction. Wind features have been removed for now. Missing sensors and stopped activity have explicit demo states. Paused activity stops the simulation clock.

Distance and time use measured canvas text widths and resize when fonts finish loading. Distance drops its decimal when rounded displayed distance reaches 1000 units. Controls cover 9.7 through 1000 km, a 1000-mile equivalent, and elapsed times through 24 hours. Inspect at **1:1** to judge device-scale readability. All values and live data are mocked; telemetry is not recorded.

## Garmin Edge 840 simulator

A native Monkey C data-field demo now lives in [`garmin/`](garmin/README.md). See that guide for SDK installation, `npm run garmin:doctor`, `npm run garmin:sim`, and native tests. This target uses built-in Garmin fonts and supports either mock data or host activity data from simulator FIT playback. See the Garmin guide for playback instructions. FIT playback has been exercised on macOS. The new heading display still needs local Garmin compilation and simulator validation because cloud Garmin downloads are blocked.

The native field follows Garmin’s unit preference and data-field background color. Use **Data Fields → Background Color → White / Black** in the simulator; the web demo retains separate theme/unit controls.

The native power and HR sections use Garmin profile zones for background color (without added zone labels). See the Garmin guide for supported zone-array formats and simulator validation. Other sections retain the host background.

## Connect IQ production port

Metric hierarchy, heading conversion, bounded power history, number formatting, and custom drawing concepts can be ported to Monkey C. The web layout is not a Garmin package; the separate native simulator demo is not yet a production sensor-integrated field. Edge 840 data-field metrics, refresh cadence, memory limits, font packaging, color rendering, and native recording coexistence still need validation against the current SDK, simulator, and hardware. No access to ClimbPro, native navigation, or training readiness is assumed.
