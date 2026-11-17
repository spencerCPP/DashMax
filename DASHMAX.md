# DashMax — Project Summary

## Goal

Build a configurable cycling dashboard for the Garmin Edge 840,
with a web designer that lets riders change their screen without
rebuilding or reinstalling the Garmin application.

DashMax is a full-page Connect IQ data field. It draws multiple
metrics within one Garmin activity data page. Garmin continues to
manage recording, activity profiles, maps, and page navigation.

## What We Have Built

### Browser dashboard prototype

Implemented with React, TypeScript, Vite, and bundled fonts.

Features include:

- A 246 × 322 logical-pixel dashboard viewport.
- Native-size and enlarged previews.
- Prominent power and heart-rate readings.
- Whole-ride averages.
- Cadence, speed, distance, and elapsed time.
- A compact power-history graph.
- Light/dark themes and metric/imperial demo controls.
- Deterministic and animated mock telemetry.
- Long-distance and long-duration layout test cases.
- Missing-sensor, paused, and missing-course demo states.

Wind was initially prototyped, then removed.
The footer now contains rider heading instead.

### Native Garmin data field

A separate Monkey C implementation lives under `garmin/`.

It targets Edge 840 and supports:

- A full-page, single-field Garmin layout.
- Mock telemetry or activity data supplied by Garmin.
- FIT playback through Garmin’s simulator.
- Trailing three-second power averaging.
- Power-history graphing.
- Missing-data handling.
- GPS travel heading when available and moving.
- Garmin-native distance and speed unit preferences.
- Garmin’s selected data-field background color.
- Individual power and HR section backgrounds based on zones.

The current project requires Connect IQ API 5.2.2 or newer.

### Garmin zone integration

Zone thresholds are read from Garmin’s user profile:

- Power: `UserProfile.getPowerZones(Activity.SPORT_CYCLING)`.
- HR: `UserProfile.getHeartRateZones2(Activity.SPORT_CYCLING)`,
  with the legacy cycling HR API as a guarded fallback.

The manifest includes the `UserProfile` permission.

Power zones are taken from the first source available:

1. Garmin's power zones, read from the user profile.
2. Garmin's FTP with fixed zone percentages: the top of zones 1 to
   6 at 55.5, 73.6, 90.7, 104.0, 122.0 and 150.7 percent of FTP.
3. Limits entered in the web designer.

With none of these, power stays uncoloured. No FTP value or
threshold is hardcoded. The percentages in step 2 are the ratios
between the test rider's Garmin Connect zone limits (126, 167,
206, 236, 277, 342 W) and their 227 W FTP, which they reproduce
exactly. Whether every Garmin account uses the same percentages
has not been confirmed.

Only the power and HR sections receive zone colors.
No additional zone labels are displayed.
Other sections retain Garmin’s selected background.

The SDK documents HR limits as:

1. Minimum zone 1.
2. Maximum zone 1.
3. Maximum zone 2.
4. Maximum zone 3.
5. Maximum zone 4.
6. Maximum zone 5.

Exact upper-bound values remain in the lower zone.

The power adapter currently expects an eight-entry min/upper-limit
array for seven zones. Other formats remain neutral and are logged
for verification.

#### Reference colors supplied by the user

| Zone | Power | Heart rate |
| --- | --- | --- |
| 1 | #a6a6a6 | #a6a6a6 |
| 2 | #3b97f3 | #3b97f3 |
| 3 | #40c35d | #40c35d |
| 4 | #faca48 | #f27716 |
| 5 | #f27716 | #e02c2c |
| 6 | #e02c2c | — |
| 7 | #6f42f3 | — |

Text is white on red/purple and black on the other backgrounds.
The Edge display may quantize RGB colors to its hardware palette.

## FIT Playback Investigation

A user-provided cycling FIT file was decoded with Garmin’s FIT SDK.

Findings:

- File integrity checks passed.
- Activity type was cycling/road.
- Recorded cadence averaged approximately 90 rpm.
- Maximum recorded cadence was 129 rpm.
- At a sample matching the simulator screenshot:
  - Recorded cadence: 86 rpm.
  - Displayed cadence: 172 rpm.
  - HR: 148 bpm.
  - Speed: approximately 23.2 km/h.
  - Three-second power: approximately 59 W.

The other readings matched, confirming doubled cadence during
that simulator playback.

DashMax’s ordinary activity adapter preserves supplied cadence.
An explicit replay workaround was added:

    npm run garmin:fit -- --cadence-divisor=2

This adjusts cadence only. It does not modify the FIT file or power.
Use the correction only where doubling has been confirmed.

## Wind Decision

The FIT file contained temperature samples but no weather messages
or wind fields.

We discussed obtaining wind from Garmin weather or an external
weather provider, but removed the feature for now.

Current direction indicator:

- Uses GPS travel heading.
- Shows a north-up arrow, compass direction, and bearing.
- Shows NO COURSE if heading is missing or speed is below 1 m/s.
- Is not a stationary magnetic compass or navigation instruction.

## Web-to-Garmin Configuration Experiment

We built a minimal end-to-end transfer test.

The first version transferred exactly three metrics and a
background colour. It has been replaced by the row builder below.

## Web Designer: Row Builder

The web designer lets a user:

1. Start from a preset: Balanced, Climbing, Wahoo style, Three
   rows, Big two, or Data dense.
2. Stack one to six rows, each small, medium or large.
3. Put one or two metrics in each row.
4. Turn on zone colouring for power, heart-rate and grade cells,
   and an
   average-and-max column for power, heart rate, cadence or speed
   in full-width rows at least 70 px tall. In a split row at least
   80 px tall, average and max stack as two small lines at the
   right, under the unit; if that would make the value smaller
   than putting them on one line beneath it, the line beneath is
   used instead.
   Power and heart rate can instead use a graph layout in
   full-width rows at least 75 px tall: the value on top and a
   history graph of the last 90 samples underneath, coloured by
   zone. In rows at least 110 px tall the graph layout also shows
   average and maximum, unless that is switched off.
   Choose left-aligned or centred text for the whole screen.
5. Select a background color.
6. Save, then edit and save that same design again.

Supported metrics:

- Power, average power, and power to weight (W/kg) using the
  rider's weight from the Garmin profile.
- Heart rate and average heart rate.
- Cadence.
- Speed and average speed.
- Distance.
- Elapsed time.
- Time of day, following the device's 12/24-hour setting.
- Current grade.
- Elevation climbed.
- Direction (N, NE, E ...) with bearing.

The stand-alone power graph row was removed once power and
heart-rate cells gained their own graph layout. Stored designs
lose such rows when the server loads them.

Rules, enforced in the designer, the server and the device:

- The shortest row must be at least 40 px tall, so a small row
  cannot sit beside too much large content.
- Row and cell boxes use the same integer maths on web and device,
  checked against the same example in both test suites.

Current grade is not supplied by Garmin to data fields. DashMax
computes it from altitude gained over distance covered in roughly
the last eight seconds, and shows `--` when nearly stationary or
without altitude. It needs comparing against Garmin's own grade
field on real rides.

Elevation climbed uses Garmin's total ascent and follows the
device's elevation unit setting, which is separate from distance.

Zone-coloured cells use the rider's Garmin zones, as on the
original dashboard. The web preview shows example colours.

Garmin has no gradient zones in the rider profile or the Connect
IQ API. The grade cell's zone colour uses the fixed bands that
Garmin's ClimbPro page draws: up to 3% green, 6% yellow, 9%
orange, 12% red, and steeper dark red. Anything under 1%,
including downhill, stays uncoloured; ClimbPro itself has no such
cut-off, but the computed grade is noisy on flat roads. The bands come from the "Understanding ClimbPro on the
Edge" guide on Garmin's forum, not from the owner's manual. The
colours (#7dbb56, #efad43, #df6336, #da3a32, #75140c) are sampled
from Garmin's climb-category swatches supplied by the user.

### Power zones on a physical Edge

On the Edge 840, `UserProfile.getPowerZones()` returns nothing even
though the rider's power zones are set in Garmin Connect. DashMax
asked under the cycling sport, the generic sport and the active
profile's sport (which reported cycling); all returned nothing. The
simulator returns zones for the same call, and heart-rate zones
work on the device. Other developers report the same on Edge 1040,
1050 and 850 on Garmin's forum, with no confirmed fix.

So the device falls back first to Garmin's FTP with Garmin's
default percentages, then to an optional Power zones section in
the designer: the top of zones 1 to 6 in watts, saved with the
design as `powerZones`.

The FTP step keeps the device in step with Garmin without manual
entry, and matches the test rider's zones exactly. A rider whose
zones use other percentages would see readings near a boundary
colour as the neighbouring zone. The Edge 840 returns the rider's
FTP (227 W) through `getFunctionalThresholdPower`, confirmed in
the server's `Device power zones:` line, which reports it as
`ftp:`. The Edge itself lists these limits as whole percents (56,
74, 91, 104, 122, 151) under nine Coggan iLevels zones; zones 8
and 9 hold nonsense values far above any real power.

The device reports what Garmin returned for power zones with each
design request, and the server logs it as `Device power zones:`.

There is one design per device. Multiple pages or profiles are not
built.

The format is defined once in `shared/design.mjs` for the web and
server, and mirrored natively in `garmin/source/DesignSync.mc`.

### Configuration service

A Node server serves the web build and JSON API.

Endpoints:

    POST /api/designs
    GET /api/designs/:id
    PUT /api/designs/:id

Each saved design has:

- A unique design ID.
- A schema version (currently 2).
- A revision number.
- Its rows, each with a size and one or two cells.
- A background RGB value.
- A contrasting foreground RGB value.
- The time it was saved, in epoch seconds.

Example:

    {
      "version": 2,
      "id": "abcdef123456",
      "revision": 2,
      "rows": [
        {"size": 3, "cells": [{"metric": "power", "zone": true}]},
        {"size": 2, "cells": [{"metric": "grade"}, {"metric": "ascent"}]}
      ],
      "background": 16776960,
      "foreground": 0,
      "savedAt": 1794873727
    }

Designs persist locally in the ignored directory:

    .dashmax-designs/

The service stores layout settings, not FIT files or ride telemetry.

Designs saved in the version 1 format are upgraded to three equal
rows when the server loads them. The device tells the server which
format it can draw; a build older than the design gets a refusal
and keeps its cached layout.

### Native fetch and rendering

The Garmin field requests:

    GET /api/designs/:id

It uses `Communications.makeWebRequest()` and the
`Communications` permission.

After receiving a response, it:

1. Validates the schema and design ID.
2. Detects a changed revision.
3. Normalizes accepted numeric values.
4. Stores the configuration in `Application.Storage`.
5. Requests a redraw.
6. Renders the selected metrics using native Garmin graphics.

The browser preview is not streamed to Garmin.
The downloaded configuration contains data, not executable code.

Invalid responses and network failures retain the last accepted
configuration.

### What We Demonstrated

The user confirmed on the Edge 840 simulator that:

- A saved web design was downloaded over HTTPS.
- The selected metrics appeared on the native screen.
- The chosen background color appeared.
- Native units followed Garmin’s setting.
- Editing and saving the same design updated the running field.
- No rebuild, reinstall, or Store publication was required for
  those configuration changes.

This validates the basic web → HTTPS → native rendering workflow.

### Development Connectivity

The test setup uses:

- A local Node designer/API server.
- A Cloudflare Quick Tunnel providing public HTTPS.
- A development launcher that embeds the server URL and design ID
  into an ignored generated build.

The tunnel URL is temporary.
A production version would use a stable backend.

On the simulator, requests use the Mac’s Internet connection.

On a physical Edge, the intended path is through the paired phone
and Garmin Connect’s Internet proxy. That hardware path still
needs testing.

## Sync Strategy

### Current implementation

The field syncs whenever no ride is in progress:

1. Display the cached layout immediately.
2. Request the latest design when DashMax starts.
3. Check again every 10 seconds.
4. After a new revision arrives, check every 5 seconds for three
   minutes, so an editing session previews quickly.
5. Retain the last valid layout if connectivity fails, and keep
   trying.

A design must never change mid-ride. Once the activity timer has
been started, no requests are sent and a response that arrives
late is dropped. A paused or stopped timer still counts as riding;
sync resumes after the ride is saved or discarded.

This means changes made while the device was off arrive at
startup, a phone that connects late is picked up, and an editing
session needs no time limit, toggle, or power cycle.

A device left on the DashMax page without starting a ride keeps
making a small request every 10 seconds through the phone.

Polling is driven from `compute()` as well as the draw path.
Whether Garmin calls `compute()` for off-screen fields, and when it
creates or retains a field instance, still needs verifying on a
physical Edge.

DashMax can display before the rider presses Start; activity
recording does not need to be running.

Sync log lines carry the device's clock time, and each applied
revision reports the seconds since the server saved it, so sync
latency can be measured from the device log.

The device also sends the revision it is showing with each request
and checks in again straight after first drawing a new one. A
`Displayed revision N` log line marks that first draw, which can
trail the `Applied` line by about a second. The server
logs `Device showing: ... revision N, S s after save`, which gives
the same measurement on the computer's clock without needing the
device log. On the physical Edge 840 the log file under
`GARMIN/APPS/LOGS` stayed empty, so this is the working method
there.

### Earlier approaches

- Polling every 15 seconds for as long as the field was active
  proved live editing, but allowed mid-ride changes and traffic
  for a whole ride.
- A two-minute startup-only window was built and validated in the
  simulator, then dropped after testing on a physical Edge: once
  the window closed, or if the phone was not connected during it,
  the only way to sync was to power-cycle the device.

### Future option: designer-signalled fast polling

The first edit of a session can take up to 10 seconds to appear,
plus the time the phone link takes. The base interval was 30
seconds at first; a 64-second save-to-screen time measured on the
Edge was too slow, so it was cut to 10.
If that proves annoying, the server could add an "editor active"
flag to the design response while the designer page is open in a
browser, and the device would poll fast whenever it sees the flag.
Having the designer open becomes the toggle. This needs a small
server and web change and a schema addition; it is not built.

### Alternatives Discussed

- Touch-based manual sync: insufficient as the only mechanism
  because the product should support non-touch devices.
- Page-navigation gestures: possible, but reliability and
  accidental activation need investigation.
- Connect IQ settings-based sync: possible candidate, but adds
  user steps and requires delivery/lifecycle validation.
- Companion phone app with push: rejected as a product requirement.

There is no confirmed server-push channel through Garmin Connect
alone for this app.

## Security and Production Ownership

The current configuration service is a single-user prototype.

Anyone who obtains a design ID can read and update that design.
Every device linked to it could receive those changes.

Before broader release, implement:

- Authenticated design ownership.
- Server-enforced authorization for edits.
- Read-only device access credentials.
- Device pairing and revocation.
- View-only sharing.
- “Use this design” creating an independent owned copy.

A design ID is an identifier, not authorization.

## Important Compatibility Fixes

Issues encountered and corrected included:

- Unsupported `Math.abs` calls in Monkey C.
- Floating-point modulo in heading normalization.
- Web-request callback typing requiring the SDK’s exact union.
- String comparisons requiring `.equals()` for decoded values.
- Numeric validation across Garmin JSON numeric types.
- Simulator output remaining attached to its original process
  output stream.
- A stack overflow on the Edge when drawing the graph layout. Data
  fields have a small stack, and the renderer nested too deeply
  with long argument lists. The design renderer now passes the
  draw mode and the current cell's box through fields, draws graph
  cells directly from the row loop, and works values out before
  the calls that use them. Crash details for a sideloaded build
  are written to `GARMIN/APPS/LOGS/CIQ_LOG.YML` on the device.
- A second stack overflow, on an ordinary cell, after the cell
  drawing function gained more local variables. Stack use grows
  with the number of variables each running function declares, not
  only with call depth. Cell drawing is now split into small steps
  that share state through fields, and the original dashboard has
  its own function so the top-level draw function stays small.
  Keep functions on the drawing path short when adding features.
- Native tests calling `Test.assertEqual` with a null value, which
  raises a type error; null checks now use `Test.assert(x == null)`.
- Native tests comparing a Float with a Number literal, which are
  never equal.
- `monkeydo` returning a non-zero exit code on a fully passing test
  run; the launcher now reads the runner's PASSED/FAILED summary.

The launcher now captures simulator output in:

    garmin/bin/simulator.log

Each launcher run streams new log output.
Existing simulators need one restart when adopting that logging
setup so output capture can be established.

## Validation Status

### Confirmed

- Web build and type checking.
- Browser controls and layout checks.
- API validation, revisions, and persistence tests.
- Local native compilation after reported compatibility fixes.
- FIT activity values reaching the native field.
- Web design downloads and native rendering in the simulator.
- Live updates to the running simulator without rebuilding.
- Full native regression suite on the local SDK (twelve tests).
- Cached design restored on restart, then replaced by a newer
  saved revision.
- Sync switching off when the activity timer starts, and a design
  saved mid-ride leaving the screen unchanged.
- Launcher reporting a passing native test run as passed.
- Row-builder layout, new metrics and heart-rate zone colour drawn
  on a physical Edge 840 from a design fetched through the phone.

### Implemented but Still Requiring Validation

- Paced pre-ride polling (10 seconds, 5 seconds after a change),
  which replaced the startup window.
- Row-builder rendering on the device: text sizing in short and
  half-width cells and the graph row.
- Centred text, the average-and-max column and the graph layout
  on the device.
- Power cell colouring on the Edge from Garmin's FTP, and from the
  designer's zones when FTP is unavailable.
- Computed grade against Garmin's own grade field.
- Garmin zone-array formats and zone-color boundary behavior.
- Heading behavior across actual device conditions.
- Physical Edge → paired phone → HTTPS service connectivity.
- Device lifecycle behavior before and during an activity.

### Not Yet Built

- Stable hosted production backend.
- Authentication and design ownership.
- Production device pairing/settings flow.
- Colour swatches chosen on the device (the Edge's backlit screen
  shifts colours; a free colour picker is misleading).
- Multiple designs per device.
- Store release and distribution workflow.

## Useful Commands

### Browser dashboard

    npm ci
    npm run dev

### Designer and API

    npm run designer

### Native mock dashboard

    npm run garmin:sim

### Native FIT playback

    npm run garmin:fit -- --cadence-divisor=2

### Web-connected three-field experiment

    npm run garmin:design -- --server=https://YOUR_SERVER --design=YOUR_DESIGN_ID

Optional FIT-backed version:

    npm run garmin:design -- --server=https://YOUR_SERVER --design=YOUR_DESIGN_ID --fit --cadence-divisor=2

### Tests

    npm test
    npm run garmin:test

### Detailed Local Setup

See:

- README.md
- garmin/README.md
- docs/designer-test.md

## Recommended Next Steps

1. Validate the row builder on the simulator and a physical Edge,
   and tune text sizing for short and half-width cells.
2. Check computed grade against Garmin's own on a real ride.
3. Deploy a stable hosted backend to replace the temporary tunnel.
4. Choose device-tested colour swatches.
5. Add ownership and read-only device authorization.
