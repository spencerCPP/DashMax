# DashMax

Interactive browser concept for a Garmin Edge 840 cycling dashboard. The screen is exactly **246 × 322 logical pixels**; preview zoom scales the same geometry. No hardware, account, weather API, or secrets are needed. Fonts are bundled locally.

## Develop

Node 24 (Node >=22.12 also supported).

```sh
npm ci
npm run dev
```

In the cloud environment use `export npm_config_cache=/workspace/.npm-cache` if the default cache is unwritable. `npm run build` type-checks and produces `dist/`. `npm test` checks rider-relative wind and unit/time formatting. `npm run preview` serves the production build.

## Demo

Light theme and metric units are the defaults. Start with deterministic telemetry, or play the repeatable 1 Hz power sequence. The trace retains 90 samples on a fixed 0–450 W scale. Averages are whole-ride mock values, not computed lap averages. Current power represents mock 3-second-smoothed readings. Reset restores the original mock state.

The wind source dot marks where ambient wind **comes from** around a fixed forward-facing rider. Relative bearing is wind-from minus course. Along-track component is ambient wind speed times cosine of relative bearing: positive headwind, negative tailwind. Initial 12 mph ambient wind projects to about 8 mph headwind; values convert together with the speed settings. This is not apparent wind. Weather can be fresh, stale, or unavailable; missing GPS course hides the relative estimate. Missing sensors and stopped activity have explicit demo states. Paused activity stops the simulation clock.

Distance and time use measured canvas text widths and resize when fonts finish loading. Distance drops its decimal when rounded displayed distance reaches 1000 units. Controls cover 9.7 through 1000 km, a 1000-mile equivalent, and elapsed times through 24 hours. Inspect at **1:1** to judge device-scale readability. All values and live data are mocked; telemetry is not recorded.

## Eventual Connect IQ port

Metric hierarchy, wind math, bounded power history, number formatting, and custom drawing concepts can be ported to Monkey C. This web layout is not a Garmin package. Edge 840 data-field metrics, weather access, refresh cadence, memory limits, font packaging, color rendering, and native recording coexistence still need validation against the current SDK, simulator, and hardware. No access to ClimbPro, native navigation, or training readiness is assumed.
