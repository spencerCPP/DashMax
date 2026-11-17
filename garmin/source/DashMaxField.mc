using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

// Select mock telemetry or host Activity.Info (including simulator FIT playback).
// Heading uses GPS course, not a weather source.
// compute() follows the host activity's update cadence; no background timers.
class DashMaxField extends WatchUi.DataField {
    var _activity = false;
    var _ride;
    var _tick = 0;
    var _lastTime = null;
    var _history;
    var _head = 0;
    var _width = 246;
    var _height = 322;
    var _ink;
    var _muted;
    var _line;
    var _accent;
    var _fonts;
    var _zones;
    var _design = null;
    var _riding = false;

    function initialize() {
        DataField.initialize();
        _ride = createRide();
        _zones = new GarminZones();
        if (BuildMode.DESIGN_SYNC) {
            _design = new DesignSync(
                BuildMode.DESIGN_SERVER,
                BuildMode.DESIGN_ID
            );
        }
        _history = new [90];
        for (var i = 0; i < 90; i += 1) {
            _history[i] = DashMath.mockPower(i - 89);
        }
        _fonts = [
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
            Graphics.FONT_TINY,
            Graphics.FONT_XTINY,
        ];
    }

    function createRide() {
        var ride = new ActivityRide();
        ride.cadenceDivisor = BuildMode.CADENCE_DIVISOR;
        return ride;
    }

    function setting(name) {
        return Application.Properties.getValue(name);
    }

    function activityMode() {
        if (BuildMode.DESIGN_SYNC) {
            return BuildMode.ACTIVITY_DATA;
        }
        return BuildMode.ACTIVITY_DATA || setting("ActivityData") == true;
    }

    function compute(info) {
        var now = (System.getTimer() / 1000).toNumber();
        // compute() carries the timer state, and also runs while another page
        // is showing.
        if (_design != null) {
            _riding = SyncPace.riding(
                info has :timerState ? info.timerState : null
            );
            _design.poll(_riding);
        }
        var activity = activityMode();
        if (activity != _activity) {
            _activity = activity;
            _ride = createRide();
            _lastTime = null;
            _head = 0;
            for (var i = 0; i < 90; i += 1) {
                _history[i] = activity ? null : DashMath.mockPower(i - 89);
            }
        }
        if (activity) {
            if (_ride.update(info, now)) {
                if (_ride.resetHistory) {
                    for (var h = 0; h < 90; h += 1) {
                        _history[h] = null;
                    }
                    _head = 0;
                }
                _history[_head] = _ride.power;
                _head = (_head + 1) % 90;
            }
            return;
        }
        if (_lastTime != now) {
            if (setting("Animate") && setting("SensorState") != 2) {
                _tick += 1;
                _history[_head] = DashMath.mockPower(_tick);
                _head = (_head + 1) % 90;
            }
            _lastTime = now;
        }
    }

    function x(n) {
        return ((n * _width) / 246.0).toNumber();
    }
    function y(n) {
        return ((n * _height) / 322.0).toNumber();
    }

    // Measure native fonts against BOTH available width and height.
    function text(dc, value, left, top, width, height, color, right) {
        var font = fit(dc, value, width, height);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x(right ? left + width : left),
            y(top),
            font,
            value,
            right ? Graphics.TEXT_JUSTIFY_RIGHT : Graphics.TEXT_JUSTIFY_LEFT
        );
    }

    function label(dc, value, left, top, width, right) {
        text(dc, value, left, top, width, 15, _muted, right);
    }

    function divider(dc, top) {
        dc.setColor(_line, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x(12), y(top), x(234), y(top));
    }

    function number(value, suffix) {
        return value == null ? "--" : value.format("%.0f") + suffix;
    }

    function speed(value, imperial) {
        return value == null
            ? "--"
            : DashMath.convert(value, imperial).format("%.1f");
    }

    function zoneBackground(dc, value, boundaries, top, height) {
        var zone = ZoneColors.index(value, boundaries);
        var selected =
            boundaries == null
                ? null
                : ZoneColors.palette(zone, boundaries.size() - 1);
        if (selected == null) {
            return;
        }
        dc.setColor(selected[0], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, y(top), _width, y(top + height) - y(top));
        _ink = selected[1] ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        _muted = _ink;
        _line = _ink;
        _accent = _ink;
    }

    function onUpdate(dc) {
        _width = dc.getWidth();
        _height = dc.getHeight();
        // Data Fields > Background Color is supplied by the host activity.
        // Re-read each redraw so host theme changes take effect in place.
        var bg = getBackgroundColor();
        var dark = bg == Graphics.COLOR_BLACK;
        // Read on every redraw so simulator/device unit changes apply in place.
        var imperial =
            System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE;
        var activity = activityMode();
        var missing = activity
            ? _ride.power == null
            : setting("SensorState") == 1;
        var stopped = !activity && setting("SensorState") == 2;
        var animate = !activity && setting("Animate");
        _ink = dark ? 0xffffff : 0x182820;
        _muted = dark ? 0xb0c0a0 : 0x506040;
        _line = dark ? 0x405040 : 0xc0c8b0;
        _accent = dark ? 0xc0e080 : 0x406020;
        dc.setColor(_ink, bg);
        dc.clear();
        if (_width < 200 || _height < 240) {
            dc.drawText(
                _width / 2,
                _height / 2 - 20,
                Graphics.FONT_XTINY,
                "Use a single-field\nfull-page layout",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        if (_design != null) {
            _design.poll(_riding);
            drawDesign(dc, imperial, activity, missing, stopped, animate);
            _design.displayed();
            return;
        }
        _zones.refresh();
        var hostInk = _ink;
        var hostMuted = _muted;
        var hostLine = _line;
        var hostAccent = _accent;
        var powerValue = activity
            ? _ride.power
            : missing
              ? null
              : stopped
                ? 0
                : animate
                  ? DashMath.mockPower(_tick)
                  : 312;
        zoneBackground(dc, powerValue, _zones.power, 0, 127);
        label(dc, "3s POWER", 12, 7, 110, false);
        label(dc, "WATTS", 176, 7, 58, true);
        var power = activity
            ? number(_ride.power, "")
            : missing
              ? "--"
              : stopped
                ? "0"
                : animate
                  ? DashMath.mockPower(_tick).format("%d")
                  : "312";
        text(dc, power, 10, 22, 145, 66, _ink, false);
        label(dc, "RIDE AVG", 164, 35, 70, true);
        text(
            dc,
            activity
                ? number(_ride.averagePower, " W")
                : missing
                  ? "--"
                  : "284 W",
            160,
            53,
            74,
            29,
            _ink,
            true
        );

        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        if (!missing) {
            for (var i = 1; i < 90; i += 1) {
                var a = _history[(_head + i - 1) % 90];
                var b = _history[(_head + i) % 90];
                if (a == null || b == null) {
                    continue;
                }
                // Keep recorded spikes within the fixed 0-450 W graph scale.
                a = a < 0 ? 0 : a > 450 ? 450 : a;
                b = b < 0 ? 0 : b > 450 ? 450 : b;
                dc.drawLine(
                    x(12 + ((i - 1) * 222.0) / 89),
                    y(121 - (a * 28.0) / 450),
                    x(12 + (i * 222.0) / 89),
                    y(121 - (b * 28.0) / 450)
                );
            }
        }
        _ink = hostInk;
        _muted = hostMuted;
        _line = hostLine;
        _accent = hostAccent;
        var hrValue = activity ? _ride.heartRate : missing ? null : 158;
        zoneBackground(dc, hrValue, _zones.heartRate, 128, 65);
        divider(dc, 127);
        label(dc, "HEART RATE", 12, 131, 115, false);
        text(
            dc,
            activity ? number(_ride.heartRate, "") : missing ? "--" : "158",
            12,
            148,
            95,
            39,
            _ink,
            false
        );
        label(dc, "bpm", 108, 166, 37, false);
        label(dc, "RIDE AVG", 164, 138, 70, true);
        text(
            dc,
            activity
                ? number(_ride.averageHeartRate, " bpm")
                : missing
                  ? "--"
                  : "142 bpm",
            154,
            158,
            80,
            27,
            _ink,
            true
        );

        _ink = hostInk;
        _muted = hostMuted;
        _line = hostLine;
        _accent = hostAccent;
        divider(dc, 193);
        label(dc, "CADENCE", 12, 198, 90, false);
        text(
            dc,
            activity
                ? number(_ride.cadence, "")
                : missing
                  ? "--"
                  : stopped
                    ? "0"
                    : "92",
            12,
            215,
            60,
            33,
            _ink,
            false
        );
        label(dc, "rpm", 76, 230, 33, false);
        dc.setColor(_line, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x(113), y(201), x(113), y(244));
        label(dc, "SPEED", 124, 198, 63, false);
        label(dc, imperial ? "mph" : "km/h", 192, 198, 42, true);
        text(
            dc,
            activity
                ? speed(_ride.speedKmh, imperial)
                : stopped
                  ? "0.0"
                  : DashMath.convert(26.8, imperial).format("%.1f"),
            124,
            215,
            110,
            31,
            _ink,
            true
        );
        label(
            dc,
            "AVG " +
                (activity
                    ? speed(_ride.averageSpeedKmh, imperial)
                    : DashMath.convert(24.1, imperial).format("%.1f")),
            124,
            245,
            110,
            true
        );

        divider(dc, 262);
        drawHeading(dc);
        var ride = setting("RideScenario");
        var km = 42.7;
        var seconds = 5784;
        if (ride == 1) {
            km = 142.7;
            seconds = 38184;
        }
        if (ride == 2) {
            km = 999.9;
            seconds = 86400;
        }
        if (ride == 3) {
            km = 1000.0;
            seconds = 86400;
        }
        if (ride == 4) {
            km = 1609.344;
            seconds = 86400;
        }
        if (animate) {
            seconds += _tick;
        }
        if (activity) {
            km = _ride.distanceKm;
            seconds = _ride.elapsedSeconds;
        }
        label(dc, "DIST", 99, 266, 55, true);
        text(
            dc,
            km == null ? "--" : DashMath.distance(km, imperial),
            96,
            283,
            62,
            22,
            _ink,
            true
        );
        label(dc, imperial ? "mi" : "km", 120, 306, 38, true);
        label(dc, "ELAPSED", 165, 266, 69, true);
        text(
            dc,
            seconds == null ? "--" : DashMath.elapsed(seconds),
            162,
            283,
            72,
            22,
            _ink,
            true
        );
        label(dc, stopped ? "PAUSED" : "TIME", 165, 306, 69, true);
    }

    // Largest native font that fits BOTH the width and height given.
    function fit(dc, value, width, height) {
        var numeric = true;
        for (var c = 0; c < value.length(); c += 1) {
            if ("0123456789.:- ".find(value.substring(c, c + 1)) == null) {
                numeric = false;
                break;
            }
        }
        for (var i = numeric ? 0 : 3; i < _fonts.size(); i += 1) {
            var candidate = _fonts[i];
            if (
                dc.getTextWidthInPixels(value, candidate) <= x(width) &&
                dc.getFontHeight(candidate) <= y(height)
            ) {
                return candidate;
            }
        }
        return Graphics.FONT_XTINY;
    }

    // [label, short label, unit, value, zone reading, zone limits] for a metric.
    function cellData(id, imperial, activity, missing, stopped, animate) {
        var speedUnit = imperial ? "mph" : "km/h";
        if (id.equals("power")) {
            var watts = activity
                ? _ride.power
                : missing
                  ? null
                  : stopped
                    ? 0
                    : animate
                      ? DashMath.mockPower(_tick)
                      : 312;
            // Garmin's own zones win; the design's are the fallback for
            // devices where Garmin returns none.
            return [
                "POWER",
                "POWER",
                "W",
                number(watts, ""),
                watts,
                _zones.power != null
                    ? _zones.power
                    : DesignConfig.powerBounds(_design.config),
            ];
        }
        if (id.equals("avgPower")) {
            var average = activity ? _ride.averagePower : missing ? null : 284;
            return ["AVG POWER", "AVG PWR", "W", number(average, ""), null, null];
        }
        if (id.equals("heartRate")) {
            var beats = activity ? _ride.heartRate : missing ? null : 158;
            return [
                "HEART RATE",
                "HR",
                "bpm",
                number(beats, ""),
                beats,
                _zones.heartRate,
            ];
        }
        if (id.equals("avgHeartRate")) {
            var averageBeats = activity
                ? _ride.averageHeartRate
                : missing
                  ? null
                  : 142;
            return [
                "AVG HEART RATE",
                "AVG HR",
                "bpm",
                number(averageBeats, ""),
                null,
                null,
            ];
        }
        if (id.equals("cadence")) {
            var turns = activity ? _ride.cadence : missing ? null : stopped ? 0 : 92;
            return ["CADENCE", "CADENCE", "rpm", number(turns, ""), null, null];
        }
        if (id.equals("speed")) {
            var kmh = activity ? _ride.speedKmh : stopped ? 0.0 : 26.8;
            return ["SPEED", "SPEED", speedUnit, speed(kmh, imperial), null, null];
        }
        if (id.equals("avgSpeed")) {
            var averageKmh = activity ? _ride.averageSpeedKmh : 24.1;
            return [
                "AVG SPEED",
                "AVG SPD",
                speedUnit,
                speed(averageKmh, imperial),
                null,
                null,
            ];
        }
        if (id.equals("distance")) {
            var km = activity ? _ride.distanceKm : 42.7;
            return [
                "DISTANCE",
                "DISTANCE",
                imperial ? "mi" : "km",
                km == null ? "--" : DashMath.distance(km, imperial),
                null,
                null,
            ];
        }
        if (id.equals("elapsed")) {
            var seconds = activity ? _ride.elapsedSeconds : 5784 + _tick;
            return [
                "ELAPSED",
                "ELAPSED",
                "",
                seconds == null ? "--" : DashMath.elapsed(seconds),
                null,
                null,
            ];
        }
        if (id.equals("grade")) {
            var slope = activity ? _ride.grade : stopped ? null : 3.2;
            return ["GRADE", "GRADE", "%", DashMath.grade(slope), null, null];
        }
        if (id.equals("ascent")) {
            // Elevation has its own unit setting, separate from distance.
            var feet =
                System.getDeviceSettings().elevationUnits ==
                System.UNIT_STATUTE;
            var climbed = activity ? _ride.ascentM : 486;
            return [
                "ASCENT",
                "ASCENT",
                feet ? "ft" : "m",
                DashMath.ascent(climbed, feet),
                null,
                null,
            ];
        }
        if (id.equals("heading")) {
            var degrees = activity
                ? _ride.headingDegrees
                : stopped
                  ? null
                  : 42.0;
            return [
                "DIRECTION",
                "DIRECTION",
                degrees == null
                    ? ""
                    : ((degrees + 0.5).toNumber() % 360).format("%d") + " deg",
                DashMath.headingName(degrees),
                null,
                null,
            ];
        }
        if (id.equals("graph")) {
            return ["POWER 90s", "POWER 90s", "", "", null, null];
        }
        return ["", "", "", "--", null, null];
    }

    function drawGraph(dc, left, top, width, height) {
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < 90; i += 1) {
            var a = _history[(_head + i - 1) % 90];
            var b = _history[(_head + i) % 90];
            if (a == null || b == null) {
                continue;
            }
            // Keep recorded spikes within the fixed 0-450 W graph scale.
            a = a < 0 ? 0 : a > 450 ? 450 : a;
            b = b < 0 ? 0 : b > 450 ? 450 : b;
            dc.drawLine(
                x(left + ((i - 1) * (width * 1.0)) / 89),
                y(top + height - (a * (height * 1.0)) / 450),
                x(left + (i * (width * 1.0)) / 89),
                y(top + height - (b * (height * 1.0)) / 450)
            );
        }
    }

    // One cell of a designed row. Coordinates are in 246 x 322 units.
    function drawCell(dc, cell, left, top, width, height, half, data) {
        var ink = _ink;
        if (cell["zone"] == true && data[5] != null) {
            var selected = ZoneColors.palette(
                ZoneColors.index(data[4], data[5]),
                data[5].size() - 1
            );
            if (selected != null) {
                dc.setColor(selected[0], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(
                    x(left),
                    y(top),
                    x(left + width) - x(left),
                    y(top + height) - y(top)
                );
                ink = selected[1] ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
            }
        }
        // Short rows tuck the label closer to the top edge.
        var compact = height < 70;
        var pad = half ? 8 : 12;
        var inner = width - 2 * pad;
        var labelTop = top + (compact ? 2 : 8);
        var valueTop = labelTop + (compact ? 15 : 18);
        var valueHeight = top + height - valueTop - (compact ? 2 : 8);
        var title = half ? data[1] : data[0];
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x(left + pad),
            y(labelTop),
            Graphics.FONT_XTINY,
            title,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        // The unit shares the label line, and is dropped if it would collide.
        if (
            data[2].length() > 0 &&
            dc.getTextWidthInPixels(title, Graphics.FONT_XTINY) +
                dc.getTextWidthInPixels(data[2], Graphics.FONT_XTINY) +
                x(6) <=
                x(inner)
        ) {
            dc.drawText(
                x(left + width - pad),
                y(labelTop),
                Graphics.FONT_XTINY,
                data[2],
                Graphics.TEXT_JUSTIFY_RIGHT
            );
        }
        if (cell["metric"].equals("graph")) {
            drawGraph(dc, left + pad, valueTop, inner, valueHeight);
            return;
        }
        var font = fit(dc, data[3], inner, valueHeight);
        var spare = y(valueHeight) - dc.getFontHeight(font);
        dc.drawText(
            x(left + pad),
            y(valueTop) + (spare > 0 ? spare / 2 : 0),
            font,
            data[3],
            Graphics.TEXT_JUSTIFY_LEFT
        );
    }

    function drawDesign(dc, imperial, activity, missing, stopped, animate) {
        var config = _design.config;
        if (config == null) {
            text(dc, "Waiting for design", 12, 125, 222, 35, _ink, false);
            label(dc, "Check the sync console", 12, 170, 222, false);
            return;
        }
        _zones.refresh();
        _design.note = _zones.powerRaw;
        _ink = config["foreground"];
        _muted = _ink;
        dc.setColor(_ink, config["background"]);
        dc.clear();
        var rows = config["rows"];
        for (var i = 0; i < rows.size(); i += 1) {
            var top = DesignConfig.rowTop(rows, i);
            var height = DesignConfig.rowTop(rows, i + 1) - top;
            var cells = rows[i]["cells"];
            var count = cells.size();
            for (var c = 0; c < count; c += 1) {
                var left = DesignConfig.cellLeft(count, c);
                drawCell(
                    dc,
                    cells[c],
                    left,
                    top,
                    DesignConfig.cellLeft(count, c + 1) - left,
                    height,
                    count > 1,
                    cellData(
                        cells[c]["metric"],
                        imperial,
                        activity,
                        missing,
                        stopped,
                        animate
                    )
                );
            }
            // Dividers go on last so zone fills do not cover them.
            dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
            if (count > 1) {
                dc.drawLine(x(123), y(top), x(123), y(top + height));
            }
            if (i > 0) {
                dc.drawLine(0, y(top), _width, y(top));
            }
        }
    }

    function drawHeading(dc) {
        var degrees = activityMode()
            ? _ride.headingDegrees
            : setting("SensorState") == 2
              ? null
              : 0.0;
        label(dc, "HEADING", 12, 266, 81, false);
        if (degrees == null) {
            text(dc, "--", 12, 283, 76, 22, _ink, false);
            label(dc, "NO COURSE", 12, 306, 81, false);
            return;
        }
        var radians = (degrees * Math.PI) / 180.0;
        // North-up arrow: 0=N (up), 90=E (right).
        var tipX = 25 + 10 * Math.sin(radians);
        var tipY = 294 - 10 * Math.cos(radians);
        var tailX = 25 - 7 * Math.sin(radians);
        var tailY = 294 + 7 * Math.cos(radians);
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x(tailX), y(tailY), x(tipX), y(tipY));
        dc.drawLine(
            x(tipX),
            y(tipY),
            x(tipX - 7 * Math.sin(radians) + 4 * Math.cos(radians)),
            y(tipY + 7 * Math.cos(radians) + 4 * Math.sin(radians))
        );
        dc.drawLine(
            x(tipX),
            y(tipY),
            x(tipX - 7 * Math.sin(radians) - 4 * Math.cos(radians)),
            y(tipY + 7 * Math.cos(radians) - 4 * Math.sin(radians))
        );
        text(dc, DashMath.headingName(degrees), 42, 283, 48, 22, _ink, false);
        var rounded = (degrees + 0.5).toNumber() % 360;
        label(dc, rounded.format("%d") + " deg", 12, 306, 81, false);
    }
}
