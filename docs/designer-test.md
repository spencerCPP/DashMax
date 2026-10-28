# Minimal web → Garmin design-sync test (macOS)

No Connect IQ Store publication is required for the **simulator** test. This experiment adds a separate three-row screen, not a full layout editor. The browser chooses exactly three distinct metrics (power, HR, distance, cadence, speed, elapsed time) and an RGB background. Save creates a design ID. Subsequent saves update that same ID; the native field fetches and caches it. The selected background is used for all three rows; zone coloring is deliberately outside this minimum test.

## 1. Start the designer and API

In Terminal at the repository root:

```sh
git pull origin main
npm ci
npm run designer
```

Open the address printed by the server (`http://localhost:4175/designer`). Choose the three metrics and background, then **Save design**. Keep the page open and note its 12-character design ID. The URL includes that ID after saving, so refreshing the page restores the saved design.

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

It should return a small JSON object with the three `fields`, RGB `background`, `foreground`, and `revision`. Keep normal TLS verification enabled.

## 3. Launch the native field (initial pairing)

In a third Terminal at the repository root:

```sh
npm run garmin:design -- --server=https://YOUR-TUNNEL.trycloudflare.com --design=YOUR_DESIGN_ID
```

Replace both placeholders with your tunnel URL and the ID shown by the web app. This builds `garmin/bin/DashMax-design.prg`, opens the actual Edge 840 simulator, and loads the separate sync-test screen. Select a single-field/full-page data-field layout.

This minimum test uses **mock telemetry by default**, so no FIT replay or sensors are needed to prove configuration transfer. Native speed/distance units still follow Garmin's setting. There is no application-settings menu to find; the URL and ID are bootstrapped into the ignored generated `garmin/bin/design-project` copy for this development test. The normal DashMax source and balanced layout are retained.

The field calls `Communications.makeWebRequest` with the `Communications` permission, using direct data-field Communications support introduced in API 5.0. The project targets API 5.2.2 or newer. Configuration is requested while the field is active, approximately every **15 seconds**; this is foreground polling, not an always-running background sync service.

The native console must report:

```text
Applied web design YOUR_DESIGN_ID revision 1
```

The device should show the selected three metrics and background. Until a valid config arrives, it shows a waiting message. The designer server logs each fetched design/revision, which helps diagnose whether requests arrive.

## 4. Prove changes arrive without rebuilding

1. Leave the simulator, API server, and HTTPS tunnel running.
2. Change a metric and the background in the browser.
3. Click **Save changes**. The ID must stay the same and the revision must increment.
4. Within approximately 15 seconds while the field is active, require a native console message for the new revision and the corresponding device-screen changes.
5. Do **not** rebuild or run the native launcher between these changes. This is the key proof that the web app is driving the screen rather than generating a new binary.

The browser preview uses mock values and web fonts. It verifies selection/order/color, not pixel-identical Garmin typography.

## 5. Prove offline behavior

After a successful sync, stop the API server or tunnel. The field must keep its last valid screen. Restart the native field with the same endpoint/ID while offline to check that `Application.Storage` restores the cached configuration. When networking is restored, saving a new revision should update it again. Failed requests, invalid JSON/configurations, duplicate metrics, or unsupported configuration versions must not replace a valid cached design.

## Optional: use FIT playback

To use activity values instead of mocks:

```sh
npm run garmin:design -- --server=https://YOUR-TUNNEL.trycloudflare.com --design=YOUR_DESIGN_ID --fit --cadence-divisor=2
```

Use the cadence correction only for the previously confirmed doubled simulator behavior. Start the recorded activity through Garmin's FIT playback controls. Missing channels show `--`. Changing metric selections in the browser still updates the same running native program without another build.

## What has and has not been validated

- **Verified in this workspace:** web build/type check; browser selection/save/update/reload; three distinct metrics; background/foreground; API validation, same-ID revisions, persistence across server restarts; HTTPS launch-option validation; generated build inputs; native source syntax.
- **Requires your local SDK:** native compilation of the new client, successful simulator HTTPS fetch, updates to the running field, offline cache restoration, and native tests (`npm run garmin:test`). The cloud environment cannot download Garmin's SDK. A passing API/browser test is not proof of native transfer.
- **Not included:** accounts, hosted production backend, production pairing flow, automatic background sync while the field is closed, arbitrary layouts, or phone settings UI integration.

A real Edge can run a development `.prg` by sideloading it into its `GARMIN/APPS` directory, without a public Store release. Testing the real phone-mediated networking path is a separate step and requires compatible device firmware, a paired connected phone, and Internet access. The simulator result alone does not verify that path. A private Store beta may be useful later to test the normal Connect IQ phone settings workflow; it is unnecessary for this initial simulator experiment.

## Troubleshooting

- **HTTP/negative request code in the native console:** first run the tunnel curl check. Confirm the tunnel/server are still running and the simulator has network connectivity enabled. Keep HTTPS enforcement on. Retain the exact response code if the request still fails.
- **404:** check the design ID and that the tunnel points to the correct local server. Designs live on the server that saved them, not on Cloudflare.
- **Waiting screen:** no valid config has arrived or been cached for that exact endpoint and ID.
- **New revision not visible:** click Save changes, check the ID did not change, keep the native field visible, wait at least 15 seconds, and inspect API/native logs.
- **Local debug edits conflict on pull:** preserve your edits before updating. Generated files under `garmin/bin` are rebuilt automatically; edit original source files instead.
