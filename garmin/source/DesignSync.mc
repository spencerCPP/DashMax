using Toybox.Activity;
using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.System;
using Toybox.WatchUi;

module DesignConfig {
    function sameString(a, b) {
        return (
            a instanceof Lang.String && b instanceof Lang.String && a.equals(b)
        );
    }
    function metric(id) {
        return (
            id instanceof Lang.String &&
            (id.equals("power") ||
                id.equals("heartRate") ||
                id.equals("distance") ||
                id.equals("cadence") ||
                id.equals("speed") ||
                id.equals("elapsed"))
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
    function problem(data) {
        if (!(data instanceof Lang.Dictionary)) {
            return "Response is not a JSON object";
        }
        if (!whole(data["version"], 1, 1)) {
            return "Unsupported configuration version";
        }
        if (!(data["id"] instanceof Lang.String) || data["id"].length() != 12) {
            return "Missing or invalid design ID";
        }
        var fields = data["fields"];
        if (!(fields instanceof Lang.Array) || fields.size() != 3) {
            return "Expected exactly three fields";
        }
        for (var i = 0; i < 3; i += 1) {
            if (!metric(fields[i])) {
                return "Unsupported metric at slot " + i.toString();
            }
        }
        if (
            sameString(fields[0], fields[1]) ||
            sameString(fields[0], fields[2]) ||
            sameString(fields[1], fields[2])
        ) {
            return "Duplicate metrics";
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
        return data;
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
                System.println("Loaded cached design " + id);
            }
        } catch (error) {
            System.println("No usable cached design");
        }
    }

    // The layout must never change mid-ride: no requests are sent while a
    // ride is in progress, and a response that lands after Start is dropped.
    function poll(riding) {
        if (riding && !_riding) {
            System.println("Design sync off while a ride is in progress");
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
                null,
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
            System.println(
                "Design request could not start; keeping cached screen"
            );
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
            System.println(
                "Design response ignored during ride; keeping current screen"
            );
            return;
        }
        if (code != 200) {
            System.println(
                "Design HTTP request failed: " +
                    code.toString() +
                    "; keeping cached screen"
            );
            return;
        }
        var reason = DesignConfig.problem(data);
        if (reason != null) {
            System.println(
                "Design rejected: " + reason + "; keeping cached screen"
            );
            return;
        }
        if (!(data instanceof Lang.Dictionary)) {
            return;
        }
        if (!DesignConfig.sameString(data["id"], _id)) {
            System.println(
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
            System.println(
                "Design applied, but offline cache could not be saved"
            );
        }
        System.println(
            "Applied web design " +
                _id +
                " revision " +
                data["revision"].toString()
        );
        WatchUi.requestUpdate();
    }
}
