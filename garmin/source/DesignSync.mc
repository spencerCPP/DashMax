using Toybox.Activity;
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

// Design format version 2: a stack of one to six rows, each small, medium or
// large (size 1-3) and holding one or two cells. The same rules live in
// shared/design.mjs for the web designer and server; change them together.
module DesignConfig {
    const SCHEMA = 2;
    const WIDTH = 246;
    const HEIGHT = 322;

    function sameString(a, b) {
        return (
            a instanceof Lang.String && b instanceof Lang.String && a.equals(b)
        );
    }
    function metric(id) {
        return (
            id instanceof Lang.String &&
            (id.equals("power") ||
                id.equals("avgPower") ||
                id.equals("heartRate") ||
                id.equals("avgHeartRate") ||
                id.equals("cadence") ||
                id.equals("speed") ||
                id.equals("avgSpeed") ||
                id.equals("distance") ||
                id.equals("elapsed") ||
                id.equals("grade") ||
                id.equals("ascent") ||
                id.equals("heading") ||
                id.equals("graph"))
        );
    }
    function whole(value, minimum, maximum) {
        if (!(
            value instanceof Lang.Number ||
            value instanceof Lang.Long ||
            value instanceof Lang.Float ||
            value instanceof Lang.Double
        )) {
            return false;
        }
        return (
            value >= minimum && value <= maximum && value == value.toNumber()
        );
    }
    function rowsProblem(rows) {
        if (
            !(rows instanceof Lang.Array) ||
            rows.size() < 1 ||
            rows.size() > 6
        ) {
            return "Expected one to six rows";
        }
        var total = 0;
        var smallest = 3;
        for (var i = 0; i < rows.size(); i += 1) {
            var row = rows[i];
            if (
                !(row instanceof Lang.Dictionary) ||
                !whole(row["size"], 1, 3)
            ) {
                return "Invalid size at row " + i.toString();
            }
            var cells = row["cells"];
            if (
                !(cells instanceof Lang.Array) ||
                cells.size() < 1 ||
                cells.size() > 2
            ) {
                return "Expected one or two cells at row " + i.toString();
            }
            for (var c = 0; c < cells.size(); c += 1) {
                var cell = cells[c];
                if (
                    !(cell instanceof Lang.Dictionary) ||
                    !metric(cell["metric"])
                ) {
                    return "Unsupported metric at row " + i.toString();
                }
                if (cell["metric"].equals("graph") && cells.size() != 1) {
                    return "Graph needs a full row";
                }
            }
            var size = row["size"].toNumber();
            total += size;
            if (size < smallest) {
                smallest = size;
            }
        }
        // Keeps the shortest row at 40 px or more on the 322 px screen.
        if (total > 8 * smallest) {
            return "Rows are too short to read";
        }
        return null;
    }
    function problem(data) {
        if (!(data instanceof Lang.Dictionary)) {
            return "Response is not a JSON object";
        }
        if (!whole(data["version"], SCHEMA, SCHEMA)) {
            return "Unsupported configuration version";
        }
        if (!(data["id"] instanceof Lang.String) || data["id"].length() != 12) {
            return "Missing or invalid design ID";
        }
        var reason = rowsProblem(data["rows"]);
        if (reason != null) {
            return reason;
        }
        var align = data["align"];
        if (
            align != null &&
            !sameString(align, "left") &&
            !sameString(align, "center")
        ) {
            return "Invalid text alignment";
        }
        if (data["powerZones"] != null && powerBounds(data) == null) {
            return "Invalid power zones";
        }
        if (!whole(data["background"], 0, 0xffffff)) {
            return "Background is not a whole RGB value";
        }
        var fg = data["foreground"];
        if (!whole(fg, 0, 0xffffff) || (fg != 0 && fg != 0xffffff)) {
            return "Foreground must be black or white";
        }
        if (!whole(data["revision"], 1, 2147483647)) {
            return "Revision is not a positive integer";
        }
        return null;
    }
    function valid(data) {
        return problem(data) == null;
    }
    function normalize(data) {
        data["version"] = data["version"].toNumber();
        data["revision"] = data["revision"].toNumber();
        data["background"] = data["background"].toNumber();
        data["foreground"] = data["foreground"].toNumber();
        var rows = data["rows"];
        for (var i = 0; i < rows.size(); i += 1) {
            rows[i]["size"] = rows[i]["size"].toNumber();
        }
        return data;
    }
    // The design may carry the top of power zones 1 to 6 in watts, for use
    // when Garmin supplies no power zones. Returns them in Garmin's layout,
    // [min zone 1, max zone 1, ... max zone 7], or null if absent or invalid.
    function powerBounds(data) {
        var zones = data["powerZones"];
        if (!(zones instanceof Lang.Array) || zones.size() != 6) {
            return null;
        }
        var bounds = [0];
        for (var i = 0; i < 6; i += 1) {
            if (
                !whole(zones[i], 1, 5000) ||
                (i > 0 && zones[i] <= zones[i - 1])
            ) {
                return null;
            }
            bounds.add(zones[i].toNumber());
        }
        // Zone 7 has no upper limit.
        bounds.add(100000);
        return bounds;
    }
    function centered(data) {
        return sameString(data["align"], "center");
    }
    // Top edge of row `index` in 322 px units; index rows.size() is the bottom.
    // Integer maths, matching layout() in shared/design.mjs.
    function rowTop(rows, index) {
        var total = 0;
        var before = 0;
        for (var i = 0; i < rows.size(); i += 1) {
            total += rows[i]["size"];
            if (i < index) {
                before += rows[i]["size"];
            }
        }
        return (HEIGHT * before) / total;
    }
    function cellLeft(count, index) {
        return (WIDTH * index) / count;
    }
}

// Sync runs whenever no ride is in progress. It checks slowly by default and
// quickly for a while after a change arrives, so an editing session previews
// promptly without a manual toggle.
module SyncPace {
    const SLOW = 30;
    const FAST = 5;
    const FAST_FOR = 180;

    // Seconds between requests, given when a new revision was last applied.
    function interval(now, changedAt) {
        return changedAt != null &&
            now >= changedAt &&
            now - changedAt <= FAST_FOR
            ? FAST
            : SLOW;
    }
    // A timer that reads earlier than the last attempt has wrapped; go again.
    function due(now, last, seconds) {
        return last == null || now < last || now - last >= seconds;
    }
    // A ride is in progress from Start until it is saved or discarded, so a
    // paused or stopped timer still counts. Unknown state does not.
    function riding(timerState) {
        return timerState != null && timerState != Activity.TIMER_STATE_OFF;
    }
}

class DesignSync {
    var config = null;
    var _server;
    var _id;
    var _lastPoll = null;
    var _changedAt = null;
    var _busy = false;
    var _riding = false;
    var _drawn = null;
    // Optional diagnostic text sent with each request for the server log.
    var note = null;

    // Prefix sync messages with the device's wall-clock time so device logs
    // can be lined up against the server's.
    function log(message) {
        var clock = System.getClockTime();
        System.println(
            clock.hour.format("%02d") +
                ":" +
                clock.min.format("%02d") +
                ":" +
                clock.sec.format("%02d") +
                " " +
                message
        );
    }

    function initialize(server, id) {
        _server = server;
        _id = id;
        try {
            var cached = Application.Storage.getValue("designer.lastConfig");
            if (
                cached instanceof Lang.Dictionary &&
                DesignConfig.sameString(cached["server"], server) &&
                DesignConfig.sameString(cached["id"], id) &&
                DesignConfig.valid(cached["config"])
            ) {
                config = DesignConfig.normalize(cached["config"]);
                log("Loaded cached design " + id);
            }
        } catch (error) {
            log("No usable cached design");
        }
    }

    // The layout must never change mid-ride: no requests are sent while a
    // ride is in progress, and a response that lands after Start is dropped.
    function poll(riding) {
        if (riding && !_riding) {
            log("Design sync off while a ride is in progress");
        }
        _riding = riding;
        var now = (System.getTimer() / 1000).toNumber();
        if (
            _riding ||
            _busy ||
            !SyncPace.due(now, _lastPoll, SyncPace.interval(now, _changedAt))
        ) {
            return;
        }
        _lastPoll = now;
        _busy = true;
        try {
            Communications.makeWebRequest(
                _server + "/api/designs/" + _id,
                // Tell the server which format this build can draw and which
                // revision is on screen, so its log shows when this device
                // picked each save up.
                {
                    "schema" => DesignConfig.SCHEMA,
                    "have" => config == null ? 0 : config["revision"],
                    "pz" => note == null ? "" : note,
                },
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :responseType
                    =>
                    Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                },
                method(:received)
            );
        } catch (error) {
            _busy = false;
            log(
                "Design request could not start; keeping cached screen"
            );
        }
    }

    // Called after the design has been drawn. Logs the first draw of each
    // revision, which is when the rider actually sees it.
    function displayed() {
        if (config == null || config["revision"] == _drawn) {
            return;
        }
        var first = _drawn == null;
        _drawn = config["revision"];
        log("Displayed revision " + _drawn.toString());
        // Check in straight away so the server learns a new revision is on
        // screen; the startup draw of the cached design needs no report.
        if (!first) {
            _lastPoll = null;
        }
    }

    // Match the SDK's callback union exactly, then narrow to JSON below.
    function received(
        code as Lang.Number,
        data as
            Null or
                Lang.ByteArray or
                Lang.Dictionary or
                Lang.String or
                PersistedContent.Iterator
    ) as Void {
        _busy = false;
        if (_riding) {
            log(
                "Design response ignored during ride; keeping current screen"
            );
            return;
        }
        if (code != 200) {
            log(
                "Design HTTP request failed: " +
                    code.toString() +
                    "; keeping cached screen"
            );
            return;
        }
        var reason = DesignConfig.problem(data);
        if (reason != null) {
            log(
                "Design rejected: " + reason + "; keeping cached screen"
            );
            return;
        }
        if (!(data instanceof Lang.Dictionary)) {
            return;
        }
        if (!DesignConfig.sameString(data["id"], _id)) {
            log(
                "Design rejected: ID mismatch; expected " +
                    _id +
                    ", received " +
                    data["id"].toString()
            );
            return;
        }
        DesignConfig.normalize(data);
        if (config != null && config["revision"] == data["revision"]) {
            return;
        }
        config = data;
        _changedAt = (System.getTimer() / 1000).toNumber();
        try {
            Application.Storage.setValue("designer.lastConfig", {
                "server" => _server,
                "id" => _id,
                "config" => data,
            });
        } catch (error) {
            log(
                "Design applied, but offline cache could not be saved"
            );
        }
        // savedAt is the server's save time in epoch seconds. The difference
        // spans two clocks, so it is only accurate to about a second.
        var delay = "";
        if (DesignConfig.whole(data["savedAt"], 1, 2147483647)) {
            var seconds = Time.now().value() - data["savedAt"].toNumber();
            delay = ", " + seconds.toString() + " s after save";
        }
        log(
            "Applied web design " +
                _id +
                " revision " +
                data["revision"].toString() +
                delay
        );
        WatchUi.requestUpdate();
    }
}
