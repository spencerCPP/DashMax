# Web designer → Garmin design-sync test (macOS)

No Connect IQ Store publication is required for the **simulator** test. The browser builds a screen from a stack of one to six rows. Each row is small, medium or large and holds one or two metrics: power, power to weight, average power, heart rate, average heart rate, cadence, speed, average speed, distance, elapsed time, time of day, current grade, elevation climbed, or direction. Power and heart-rate cells can take a zone colour from the rider's Garmin zones. Power, heart rate, cadence and speed can show ride average and maximum beside the value when they have a full-width row at least 70 px tall. Power and heart rate can instead use a graph layout in a full-width row at least 75 px tall: the value above a zone-coloured history graph, plus average and maximum when the row is at least 110 px tall and they are not switched off. Text can be left-aligned or centred. Presets (Balanced, Climbing, Wahoo style, Three rows, Big two, Data dense) give a starting point. An optional Power zones section takes the top of zones 1 to 6 in watts; the device prefers Garmin's own power zones, then zones worked out from Garmin's FTP, and uses these only when it has neither. A physical Edge 840 currently returns no power zones. Save creates a design ID. Subsequent saves update that same ID; the native field fetches and caches it. The format and its rules are defined in `shared/design.mjs` and mirrored natively in `garmin/source/DesignSync.mc`.

## 1. Start the designer and API

In Terminal at the repository root:

```sh
git pull origin main
npm ci
npm run designer
```

Open the address printed by the server (`http://localhost:4175/designer`). Pick a preset or build your rows, choose a background, then **Save design**. Keep the page open and note its 12-character design ID. The URL includes that ID after saving, so refreshing the page restores the saved design.

The Node server serves both the web build and JSON API. Designs are persisted locally in ignored `.dashmax-designs/designs.json`. Keep the server running. No FIT files or ride telemetry are sent to this server.

## 2. Give the simulator a public HTTPS endpoint

In a second Terminal, use a Cloudflare Quick Tunnel. If needed, install Cloudflare's client using Homebrew:

```sh
brew install cloudflared
cloudflared tunnel --url http://127.0.0.1:4175
```

Use the **https://…trycloudflare.com** URL printed by cloudflared as the server URL below. Keep the tunnel running. This provides a normally trusted HTTPS certificate without disabling simulator HTTPS requirements or certificate verification. The backend remains bound to loopback; the tunnel exposes the development designer/API. This is a single-user prototype with no account system; possession of a design ID permits reading/updating that nonsensitive design. It is not a production authenticated service.

A tunnel URL is temporary. If you restart the tunnel and receive a new URL, rerun the native launch command with the new URL. A stable deployed HTTPS endpoint would be built into a released app instead.

Verify the tunnel is serving the saved configuration before launching:

```sh
curl --fail 'https://YOUR-TUNNEL.trycloudflare.com/api/designs/YOUR_DESIGN_ID'
```

It should return a small JSON object with `rows`, RGB `background`, `foreground`, and `revision`. Keep normal TLS verification enabled.

## 3. Launch the native field (initial pairing)

In a third Terminal at the repository root:

```sh
npm run garmin:design -- --server=https://YOUR-TUNNEL.trycloudflare.com --design=YOUR_DESIGN_ID
```

Replace both placeholders with your tunnel URL and the ID shown by the web app. This builds `garmin/bin/DashMax-design.prg`, opens the actual Edge 840 simulator, and loads the separate sync-test screen. Select a single-field/full-page data-field layout.

This minimum test uses **mock telemetry by default**, so no FIT replay or sensors are needed to prove configuration transfer. Native speed/distance units still follow Garmin's setting. There is no application-settings menu to find; the URL and ID are bootstrapped into the ignored generated `garmin/bin/design-project` copy for this development test. The normal DashMax source and balanced layout are retained.

The field calls `Communications.makeWebRequest` with the `Communications` permission, using direct data-field Communications support introduced in API 5.0. The project targets API 5.2.2 or newer. The cached design is shown immediately and the first request is sent when the field starts. After that the field checks for a new revision whenever no ride is in progress: approximately every **10 seconds** by default, and every **5 seconds** for three minutes after a change arrives, so an editing session previews quickly. Once the activity timer has been started, no requests are sent and any late response is dropped, until the ride is saved or discarded. This is foreground polling, not an always-running background sync service.

The native console must report:

```text
14:02:07 Applied web design YOUR_DESIGN_ID revision 1, 3 s after save
```

Sync messages start with the device's clock time. `Applied` marks the moment the response was accepted; a following `Displayed revision N` line marks the first time that revision was drawn, which can be up to about a second later because Garmin redraws data fields on its own schedule. The trailing figure is the time between the server saving that revision and the device applying it; it compares the computer's clock with the device's, so treat it as accurate to about a second. The server prefixes its own `Design saved` and `Design fetched` lines with the computer's clock time.

The device also tells the server which revision it is showing, and checks in again straight after first drawing a new one. The designer Terminal then prints, for example:

```text
14:02:08 Device showing: YOUR_DESIGN_ID revision 4, 4 s after save
```

This measures save-to-screen time on the computer's clock alone, and works on a physical Edge without reading its log file over USB. It includes the extra check-in request, so it reads a second or two longer than the device's own figure.

The device should show the designed rows and background. Until a valid config arrives, it shows a waiting message. The designer server logs each fetched design/revision, which helps diagnose whether requests arrive.

## 4. Prove changes arrive without rebuilding

1. Leave the simulator, API server, and HTTPS tunnel running.
2. Change a metric and the background in the browser.
3. Without starting the activity timer, click **Save changes**. The ID must stay the same and the revision must increment.
4. Within approximately 10 seconds for the first change, and 5 seconds for changes made in the next three minutes, require a native console message for the new revision and the corresponding device-screen changes.
5. Do **not** rebuild or run the native launcher between these changes. This is the key proof that the web app is driving the screen rather than generating a new binary.

The browser preview uses mock values and web fonts. It verifies selection/order/color, not pixel-identical Garmin typography.

## 5. Prove offline behavior

After a successful sync, stop the API server or tunnel. The field must keep its last valid screen. Restart the native field with the same endpoint/ID while offline to check that `Application.Storage` restores the cached configuration. When networking is restored, saving a new revision should update it again. Failed requests, invalid JSON/configurations, layouts that break the row rules, or unsupported configuration versions must not replace a valid cached design.

## Optional: use FIT playback

To use activity values instead of mocks:

```sh
npm run garmin:design -- --server=https://YOUR-TUNNEL.trycloudflare.com --design=YOUR_DESIGN_ID --fit --cadence-divisor=2
```

Use the cadence correction only for the previously confirmed doubled simulator behavior. Start the recorded activity through Garmin's FIT playback controls. Missing channels show `--`. Changing metric selections in the browser still updates the same running native program without another build, but only before the activity timer starts. If playback starts the timer, sync stops and the console prints `Design sync off while a ride is in progress`, so save design changes before starting playback.

## What has and has not been validated

- **Verified in this workspace:** web build/type check; browser selection/save/update/reload; row builder, presets and layout rules; background/foreground; API validation, same-ID revisions, persistence across server restarts; HTTPS launch-option validation; generated build inputs; native source syntax.
- **Requires your local SDK:** native compilation of the new client, successful simulator HTTPS fetch, updates to the running field, offline cache restoration, and native tests (`npm run garmin:test`). The cloud environment cannot download Garmin's SDK. A passing API/browser test is not proof of native transfer.
- **Not included:** accounts, hosted production backend, production pairing flow, automatic background sync while the field is closed, arbitrary layouts, or phone settings UI integration.

A real Edge can run a development `.prg` by sideloading it into its `GARMIN/APPS` directory, without a public Store release. Testing the real phone-mediated networking path is a separate step and requires compatible device firmware, a paired connected phone, and Internet access. The simulator result alone does not verify that path. A private Store beta may be useful later to test the normal Connect IQ phone settings workflow; it is unnecessary for this initial simulator experiment.

## Troubleshooting

- **HTTP/negative request code in the native console:** first run the tunnel curl check. Confirm the tunnel/server are still running and the simulator has network connectivity enabled. Keep HTTPS enforcement on. Retain the exact response code if the request still fails.
- **404:** check the design ID and that the tunnel points to the correct local server. Designs live on the server that saved them, not on Cloudflare.
- **Waiting screen:** no valid config has arrived or been cached for that exact endpoint and ID.
- **New revision not visible:** click Save changes, check the ID did not change, wait at least 30 seconds, and inspect API/native logs. If the console shows `Design sync off while a ride is in progress`, the activity timer is running; save or discard the activity to resume sync.
- **Local debug edits conflict on pull:** preserve your edits before updating. Generated files under `garmin/bin` are rebuilt automatically; edit original source files instead.
