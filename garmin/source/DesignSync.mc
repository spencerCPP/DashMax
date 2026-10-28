using Toybox.Application;
using Toybox.Communications;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

module DesignConfig {
    function metric(id) {
        return (
            id == "power" ||
            id == "heartRate" ||
            id == "distance" ||
            id == "cadence" ||
            id == "speed" ||
            id == "elapsed"
        );
    }
    function valid(data) {
        if (!(data instanceof Lang.Dictionary) || data["version"] != 1) {
            return false;
        }
        var fields = data["fields"];
        if (!(fields instanceof Lang.Array) || fields.size() != 3) {
            return false;
        }
        if (!metric(fields[0]) || !metric(fields[1]) || !metric(fields[2])) {
            return false;
        }
        if (
            fields[0] == fields[1] ||
            fields[0] == fields[2] ||
            fields[1] == fields[2]
        ) {
            return false;
        }
        var bg = data["background"];
        var fg = data["foreground"];
        return (
            bg instanceof Lang.Number &&
            bg >= 0 &&
            bg <= 0xffffff &&
            (fg == 0 || fg == 0xffffff) &&
            data["revision"] instanceof Lang.Number &&
            data["revision"] > 0
        );
    }
}

class DesignSync {
    var config = null;
    var _server;
    var _id;
    var _lastPoll = null;
    var _busy = false;

    function initialize(server, id) {
        _server = server;
        _id = id;
        try {
            var cached = Application.Storage.getValue("designer.lastConfig");
            if (
                cached instanceof Lang.Dictionary &&
                cached["server"] == server &&
                cached["id"] == id &&
                DesignConfig.valid(cached["config"])
            ) {
                config = cached["config"];
                System.println("Loaded cached design " + id);
            }
        } catch (error) {
            System.println("No usable cached design");
        }
    }

    function poll() {
        var now = (System.getTimer() / 1000).toNumber();
        if (
            _busy ||
            (_lastPoll != null && now >= _lastPoll && now - _lastPoll < 15)
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

    function received(code, data) {
        _busy = false;
        if (code != 200 || !DesignConfig.valid(data) || data["id"] != _id) {
            System.println(
                "Design sync failed or invalid response, code " +
                    code.toString() +
                    "; keeping cached screen"
            );
            return;
        }
        if (config != null && config["revision"] == data["revision"]) {
            return;
        }
        config = data;
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
