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
    var _heartHistory;
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
    // The stack available to a data field is small. The design renderer keeps
    // call chains short and argument lists small by passing the draw mode and
    // the current cell's box through these fields instead of parameters.
    var _drawImperial = false;
    var _drawActivity = false;
    var _drawMissing = false;
    var _drawStopped = false;
    var _drawAnimate = false;
    var _boxLeft = 0;
    var _boxTop = 0;
    var _boxWidth = 0;
    var _boxHeight = 0;
    // The cell being drawn, and what its drawing steps share.
    var _cell = null;
    var _data = null;
    var _stats = null;
    var _half = false;
    var _center = false;
    var _cellInk = 0;
    var _pad = 12;
    var _valueTop = 0;
    var _valueHeight = 0;
    var _valueRoom = 0;
    var _labelFont = Graphics.FONT_XTINY;

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
        _heartHistory = new [90];
        for (var i = 0; i < 90; i += 1) {
            _history[i] = DashMath.mockPower(i - 89);
            _heartHistory[i] = DashMath.mockHeartRate(i - 89);
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
                _heartHistory[i] = activity
                    ? null
                    : DashMath.mockHeartRate(i - 89);
            }
        }
        if (activity) {
            if (_ride.update(info, now)) {
                if (_ride.resetHistory) {
                    for (var h = 0; h < 90; h += 1) {
                        _history[h] = null;
                        _heartHistory[h] = null;
                    }
                    _head = 0;
                }
                _history[_head] = _ride.power;
                _heartHistory[_head] = _ride.heartRate;
                _head = (_head + 1) % 90;
            }
            return;
        }
        if (_lastTime != now) {
            if (setting("Animate") && setting("SensorState") != 2) {
                _tick += 1;
                _history[_head] = DashMath.mockPower(_tick);
                _heartHistory[_head] = DashMath.mockHeartRate(_tick);
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

        // The draw mode travels in fields, and each screen is drawn by its
        // own function, so this one holds very little stack.
        _drawImperial = imperial;
        _drawActivity = activity;
        _drawMissing = missing;
        _drawStopped = stopped;
        _drawAnimate = animate;
        if (BuildMode.COLOR_TEST) {
            drawColorTest(dc);
            return;
        }
        if (_design != null) {
            _design.poll(_riding);
            drawDesign(dc);
            _design.displayed();
            return;
        }
        drawDashboard(dc);
    }

    // Colour test screen: each zone colour (rows 1-7) beside lighter mixes of
    // it with white (columns A-D: 0, 25, 45 and 65 percent white), with a
    // sample number, for choosing colours that read well on the real screen.
    function drawColorTest(dc) {
        var bases = [
            0xa6a6a6,
            0x3b97f3,
            0x40c35d,
            0xfaca48,
            0xf27716,
            0xe02c2c,
            0x6f42f3,
        ];
        var mixes = [0, 25, 45, 65];
        var letters = ["A", "B", "C", "D"];
        for (var i = 0; i < 28; i += 1) {
            var row = i / 4;
            var col = i % 4;
            var color = mixColor(bases[row], mixes[col]);
            var left = x(col * 61.5);
            var top = y(row * 46);
            dc.setColor(color, color);
            dc.fillRectangle(left, top, x((col + 1) * 61.5) - left, y((row + 1) * 46) - top);
            dc.setColor(
                textOn(color),
                Graphics.COLOR_TRANSPARENT
            );
            dc.drawText(
                left + 3,
                top + 1,
                Graphics.FONT_XTINY,
                (row + 1).toString() + letters[col],
                Graphics.TEXT_JUSTIFY_LEFT
            );
            dc.drawText(
                left + x(30.75),
                top + y(14),
                Graphics.FONT_MEDIUM,
                "146",
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
    }

    // A colour mixed with white by the given percentage.
    function mixColor(color, percent) {
        var red = (color >> 16) & 0xff;
        var green = (color >> 8) & 0xff;
        var blue = color & 0xff;
        red = red + ((255 - red) * percent) / 100;
        green = green + ((255 - green) * percent) / 100;
        blue = blue + ((255 - blue) * percent) / 100;
        return (red << 16) | (green << 8) | blue;
    }

    // Black or white text, whichever reads better on the colour.
    function textOn(color) {
        var bright =
            ((color >> 16) & 0xff) * 299 +
            ((color >> 8) & 0xff) * 587 +
            (color & 0xff) * 114;
        return bright < 140000 ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    // The original fixed dashboard.
    function drawDashboard(dc) {
        var imperial = _drawImperial;
        var activity = _drawActivity;
        var missing = _drawMissing;
        var stopped = _drawStopped;
        var animate = _drawAnimate;
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
        // Scaled in place rather than through x() and y(), to stay shallow.
        var widest = ((width * _width) / 246.0).toNumber();
        var tallest = ((height * _height) / 322.0).toNumber();
        var numeric = true;
        for (var c = 0; c < value.length(); c += 1) {
            var character = value.substring(c, c + 1);
            if ("0123456789.:- ".find(character) == null) {
                numeric = false;
                break;
            }
        }
        for (var i = numeric ? 0 : 3; i < _fonts.size(); i += 1) {
            var candidate = _fonts[i];
            var wide = dc.getTextWidthInPixels(value, candidate);
            if (wide > widest) {
                continue;
            }
            var tall = dc.getFontHeight(candidate);
            if (tall <= tallest) {
                return candidate;
            }
        }
        return Graphics.FONT_XTINY;
    }

    // [label, short label, unit, value, zone reading, zone limits] for a metric.
    // The draw mode comes from fields set by onUpdate, to keep calls shallow.
    function cellData(id) {
        var speedUnit = _drawImperial ? "mph" : "km/h";
        if (id.equals("power")) {
            var watts = _drawActivity
                ? _ride.power
                : _drawMissing
                  ? null
                  : _drawStopped
                    ? 0
                    : _drawAnimate
                      ? DashMath.mockPower(_tick)
                      : 312;
            // Garmin's own zones win, then zones from Garmin's FTP, then the
            // limits entered in the designer.
            return [
                "POWER",
                "POWER",
                "W",
                number(watts, ""),
                watts,
                _zones.power != null
                    ? _zones.power
                    : _zones.powerFromFtp != null
                      ? _zones.powerFromFtp
                      : DesignConfig.powerBounds(_design.config),
            ];
        }
        if (id.equals("wkg")) {
            // Live power over the rider's Garmin profile weight; coloured by
            // the same power zones as the power cell.
            var perKgWatts = _drawActivity
                ? _ride.power
                : _drawMissing
                  ? null
                  : _drawStopped
                    ? 0
                    : _drawAnimate
                      ? DashMath.mockPower(_tick)
                      : 312;
            return [
                "WATTS/KG",
                "W/KG",
                "",
                DashMath.perKg(perKgWatts, _zones.weightGrams),
                perKgWatts,
                _zones.power != null
                    ? _zones.power
                    : _zones.powerFromFtp != null
                      ? _zones.powerFromFtp
                      : DesignConfig.powerBounds(_design.config),
            ];
        }
        if (id.equals("avgPower")) {
            var average = _drawActivity ? _ride.averagePower : _drawMissing ? null : 284;
            return ["AVG POWER", "AVG PWR", "W", number(average, ""), null, null];
        }
        if (id.equals("heartRate")) {
            var beats = _drawActivity ? _ride.heartRate : _drawMissing ? null : 158;
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
            var averageBeats = _drawActivity
                ? _ride.averageHeartRate
                : _drawMissing
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
            var turns = _drawActivity ? _ride.cadence : _drawMissing ? null : _drawStopped ? 0 : 92;
            return ["CADENCE", "CADENCE", "rpm", number(turns, ""), null, null];
        }
        if (id.equals("speed")) {
            var kmh = _drawActivity ? _ride.speedKmh : _drawStopped ? 0.0 : 26.8;
            return ["SPEED", "SPEED", speedUnit, speed(kmh, _drawImperial), null, null];
        }
        if (id.equals("avgSpeed")) {
            var averageKmh = _drawActivity ? _ride.averageSpeedKmh : 24.1;
            return [
                "AVG SPEED",
                "AVG SPD",
                speedUnit,
                speed(averageKmh, _drawImperial),
                null,
                null,
            ];
        }
        if (id.equals("distance")) {
            var km = _drawActivity ? _ride.distanceKm : 42.7;
            return [
                "DISTANCE",
                "DISTANCE",
                _drawImperial ? "mi" : "km",
                km == null ? "--" : DashMath.distance(km, _drawImperial),
                null,
                null,
            ];
        }
        if (id.equals("elapsed")) {
            var seconds = _drawActivity ? _ride.elapsedSeconds : 5784 + _tick;
            return [
                "ELAPSED",
                "ELAPSED",
                "",
                seconds == null ? "--" : DashMath.elapsed(seconds),
                null,
                null,
            ];
        }
        if (id.equals("clock")) {
            // Follows the device's 12/24-hour setting.
            var now = System.getClockTime();
            var time = DashMath.clock(
                now.hour,
                now.min,
                System.getDeviceSettings().is24Hour
            );
            return ["TIME OF DAY", "TIME", time[1], time[0], null, null];
        }
        if (id.equals("grade")) {
            var slope = _drawActivity ? _ride.grade : _drawStopped ? null : 3.2;
            return ["GRADE", "GRADE", "%", DashMath.grade(slope), slope, null];
        }
        if (id.equals("ascent")) {
            // Elevation has its own unit setting, separate from distance.
            var feet =
                System.getDeviceSettings().elevationUnits ==
                System.UNIT_STATUTE;
            var climbed = _drawActivity ? _ride.ascentM : 486;
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
            var degrees = _drawActivity
                ? _ride.headingDegrees
                : _drawStopped
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
        return ["", "", "", "--", null, null];
    }

    // [average, maximum] as text for metrics Garmin tracks both for, else null.
    function cellStats(id) {
        if (id.equals("power")) {
            return _drawActivity
                ? [number(_ride.averagePower, ""), number(_ride.maxPower, "")]
                : _drawMissing
                  ? ["--", "--"]
                  : ["284", "612"];
        }
        if (id.equals("heartRate")) {
            return _drawActivity
                ? [
                      number(_ride.averageHeartRate, ""),
                      number(_ride.maxHeartRate, ""),
                  ]
                : _drawMissing
                  ? ["--", "--"]
                  : ["142", "171"];
        }
        if (id.equals("cadence")) {
            return _drawActivity
                ? [
                      number(_ride.averageCadence, ""),
                      number(_ride.maxCadence, ""),
                  ]
                : _drawMissing
                  ? ["--", "--"]
                  : ["88", "118"];
        }
        if (id.equals("speed")) {
            return _drawActivity
                ? [
                      speed(_ride.averageSpeedKmh, _drawImperial),
                      speed(_ride.maxSpeedKmh, _drawImperial),
                  ]
                : [speed(24.1, _drawImperial), speed(52.3, _drawImperial)];
        }
        return null;
    }

    // [lowest value drawn, value span] for a history graph, or null when the
    // history is empty. Power is drawn from zero; heart rate from just under
    // its lowest sample.
    function graphRange(history, fromZero) {
        var low = null;
        var high = null;
        for (var i = 0; i < 90; i += 1) {
            var sample = history[i];
            if (sample == null) {
                continue;
            }
            if (low == null || sample < low) {
                low = sample;
            }
            if (high == null || sample > high) {
                high = sample;
            }
        }
        if (high == null) {
            return null;
        }
        low = fromZero ? 0 : low - 10;
        high = high + 5;
        if (high - low < 20) {
            high = low + 20;
        }
        return [low, (high - low) * 1.0];
    }

    // One colour per zone, looked up once per graph, or null without zones.
    function zoneColorTable(bounds) {
        if (bounds == null) {
            return null;
        }
        var count = bounds.size() - 1;
        var colors = new [count];
        for (var z = 0; z < count; z += 1) {
            var entry = ZoneColors.palette(z, count);
            colors[z] = entry == null ? 0xa6a6a6 : entry[0];
        }
        return colors;
    }

    // Filled history graph in the current box, coloured by zone under an
    // outline, scaled to the range of the samples shown.
    function drawZoneGraph(dc, history, bounds, fromZero) {
        var range = graphRange(history, fromZero);
        if (range == null) {
            return;
        }
        var colors = zoneColorTable(bounds);
        var bottom = y(_boxTop + _boxHeight);
        var full = bottom - y(_boxTop);
        var first = x(_boxLeft);
        var columns = x(_boxLeft + _boxWidth) - first;
        if (columns < 2) {
            return;
        }
        // One column per pixel, with the height sloped between neighbouring
        // samples, then an outline joining the column tops.
        var scale = 89.0 / (columns - 1);
        var lastTop = null;
        for (var p = 0; p < columns; p += 1) {
            var index = (p * scale).toNumber();
            var value = history[(_head + index) % 90];
            if (value == null) {
                lastTop = null;
                continue;
            }
            if (index < 89) {
                var next = history[(_head + index + 1) % 90];
                if (next != null) {
                    value = value + (next - value) * (p * scale - index);
                }
            }
            var color = 0xa6a6a6;
            if (colors != null) {
                var zone = ZoneColors.index(value, bounds);
                if (zone != null) {
                    color = colors[zone];
                }
            }
            var tall = (((value - range[0]) / range[1]) * full).toNumber();
            if (tall < 1) {
                tall = 1;
            } else if (tall > full) {
                tall = full;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(first + p, bottom - tall, 1, tall);
            dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
            if (lastTop == null) {
                dc.drawPoint(first + p, bottom - tall);
            } else {
                dc.drawLine(first + p - 1, lastTop, first + p, bottom - tall);
            }
            lastTop = bottom - tall;
        }
    }

    // A full-width power or heart-rate cell in the current box: the value on
    // top, with average and maximum beside it when _stats is set, and a
    // zone-coloured history graph underneath.
    function drawGraphCell(dc, history) {
        var valueTop = _boxTop + 6 + pickLabelFont(dc, _boxHeight);
        var band = _boxTop + _boxHeight - valueTop - 4;
        var valueHeight = band * 0.45;
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        var px = x(_boxLeft + 12);
        var py = y(_boxTop + 6);
        dc.drawText(
            px,
            py,
            _labelFont,
            _data[0],
            Graphics.TEXT_JUSTIFY_LEFT
        );
        px = x(_boxLeft + _boxWidth - 12);
        dc.drawText(
            px,
            py,
            _labelFont,
            _data[2],
            Graphics.TEXT_JUSTIFY_RIGHT
        );
        var font = null;
        var room = _boxWidth - 24;
        if (_stats != null) {
            // Average and maximum, stacked at the right.
            room = _boxWidth - 120;
            var line = "AVG " + _stats[0];
            font = fit(dc, line, 90, valueHeight / 2.0);
            py = y(valueTop);
            dc.drawText(px, py, font, line, Graphics.TEXT_JUSTIFY_RIGHT);
            line = "MAX " + _stats[1];
            font = fit(dc, line, 90, valueHeight / 2.0);
            py = y(valueTop + valueHeight / 2.0);
            dc.drawText(px, py, font, line, Graphics.TEXT_JUSTIFY_RIGHT);
        }
        // The live value, vertically centred in its band.
        font = fit(dc, _data[3], room, valueHeight);
        py = y(valueHeight) - dc.getFontHeight(font);
        py = y(valueTop) + (py > 0 ? py / 2 : 0);
        if (_center) {
            px = x(_boxLeft + 12 + room / 2.0);
            dc.drawText(px, py, font, _data[3], Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            px = x(_boxLeft + 12);
            dc.drawText(px, py, font, _data[3], Graphics.TEXT_JUSTIFY_LEFT);
        }
        // Hand the graph its own box.
        _boxLeft = _boxLeft + 12;
        _boxWidth = _boxWidth - 24;
        _boxTop = valueTop + valueHeight + 3;
        _boxHeight = band - valueHeight - 3;
        drawZoneGraph(dc, history, _data[5], _data[1].equals("POWER"));
    }

    // Fills the current cell with its zone colour, if it has one, and sets
    // the ink the rest of the cell is drawn in. Grade has fixed bands; power
    // and heart rate use rider zones.
    function drawZoneFill(dc) {
        var selected = null;
        if (_cell["metric"].equals("grade")) {
            selected = ZoneColors.grade(_data[4]);
        } else if (_data[5] != null) {
            var zone = ZoneColors.index(_data[4], _data[5]);
            selected = ZoneColors.palette(zone, _data[5].size() - 1);
        }
        if (selected == null) {
            return;
        }
        var px = x(_boxLeft);
        var py = y(_boxTop);
        dc.setColor(selected[0], Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(
            px,
            py,
            x(_boxLeft + _boxWidth) - px,
            y(_boxTop + _boxHeight) - py
        );
        _cellInk = selected[1] ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    // Label font for a cell of the given height (322-unit): Garmin's xtiny
    // (about 11 px) in short rows, tiny (13 px) in medium, small (16 px) in
    // large. Sets _labelFont and returns its height in 322 units.
    function pickLabelFont(dc, height) {
        _labelFont =
            height < 70
                ? Graphics.FONT_XTINY
                : height < 110
                  ? Graphics.FONT_TINY
                  : Graphics.FONT_SMALL;
        return (dc.getFontHeight(_labelFont) * 322.0) / _height;
    }

    // The label line of the current cell. The unit shares the line, and is
    // dropped if it would collide with the label.
    function drawCellLabel(dc, labelTop) {
        var title = _half ? _data[1] : _data[0];
        var unit = _data[2];
        var fits = false;
        if (unit.length() > 0) {
            var wide = dc.getTextWidthInPixels(title, _labelFont);
            wide += dc.getTextWidthInPixels(unit, _labelFont);
            fits = wide + x(6) <= x(_boxWidth - 2 * _pad);
        }
        var py = y(labelTop);
        if (_center) {
            if (fits) {
                title = title + " " + unit;
            }
            dc.drawText(
                x(_boxLeft + _boxWidth / 2.0),
                py,
                _labelFont,
                title,
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }
        dc.drawText(
            x(_boxLeft + _pad),
            py,
            _labelFont,
            title,
            Graphics.TEXT_JUSTIFY_LEFT
        );
        if (fits) {
            dc.drawText(
                x(_boxLeft + _boxWidth - _pad),
                py,
                _labelFont,
                unit,
                Graphics.TEXT_JUSTIFY_RIGHT
            );
        }
    }

    // Average and maximum as a two-line column at the right of a full-width
    // cell. Narrows the room left for the value.
    function drawFullStats(dc) {
        _valueRoom = _valueRoom - 96;
        var px = x(_boxLeft + _boxWidth - _pad);
        for (var s = 0; s < 2; s += 1) {
            var line = (s == 0 ? "AVG " : "MAX ") + _stats[s];
            var font = fit(dc, line, 90, _valueHeight / 2.0);
            var py = y(_valueHeight / 2.0) - dc.getFontHeight(font);
            py = y(_valueTop + (s * _valueHeight) / 2.0) + (py > 0 ? py / 2 : 0);
            dc.drawText(px, py, font, line, Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    // Average and maximum in a half-width cell. Preferred: two small lines at
    // the right, under the unit, with the value beside them; this draws the
    // value too and returns true. That layout is used whenever it leaves the
    // value at least as large as the alternative, one small line under the
    // value, which this draws before returning false.
    function drawHalfStats(dc) {
        var average = "AVG " + _stats[0];
        var most = "MAX " + _stats[1];
        var stackWide = dc.getTextWidthInPixels(average, Graphics.FONT_TINY);
        var lineTall = dc.getTextWidthInPixels(most, Graphics.FONT_TINY);
        if (lineTall > stackWide) {
            stackWide = lineTall;
        }
        lineTall = dc.getFontHeight(Graphics.FONT_TINY);
        // fit() takes 246-unit widths; the stack was measured in pixels.
        var beside = _valueRoom - 6 - (stackWide * 246.0) / _width;
        var font = fit(dc, _data[3], beside, _valueHeight);
        var tall = dc.getFontHeight(font);
        var px = x(_boxLeft + _boxWidth - _pad);
        var py = y(_valueHeight);
        if (2 * lineTall <= py) {
            var under = fit(dc, _data[3], _valueRoom, _valueHeight - 20);
            if (tall >= dc.getFontHeight(under)) {
                under = y(_valueTop) + (py - 2 * lineTall) / 2;
                dc.drawText(
                    px,
                    under,
                    Graphics.FONT_TINY,
                    average,
                    Graphics.TEXT_JUSTIFY_RIGHT
                );
                dc.drawText(
                    px,
                    under + lineTall,
                    Graphics.FONT_TINY,
                    most,
                    Graphics.TEXT_JUSTIFY_RIGHT
                );
                py = y(_valueTop) + (py > tall ? (py - tall) / 2 : 0);
                if (_center) {
                    px = x(_boxLeft + _pad + beside / 2.0);
                    dc.drawText(
                        px,
                        py,
                        font,
                        _data[3],
                        Graphics.TEXT_JUSTIFY_CENTER
                    );
                } else {
                    px = x(_boxLeft + _pad);
                    dc.drawText(
                        px,
                        py,
                        font,
                        _data[3],
                        Graphics.TEXT_JUSTIFY_LEFT
                    );
                }
                return true;
            }
        }
        // One small line under the value, shortened if it is too wide.
        _valueHeight = _valueHeight - 20;
        average = average + "  " + most;
        if (
            dc.getTextWidthInPixels(average, Graphics.FONT_TINY) >
            x(_valueRoom)
        ) {
            average = "A " + _stats[0] + "  M " + _stats[1];
        }
        py = y(_valueTop + _valueHeight);
        if (_center) {
            px = x(_boxLeft + _boxWidth / 2.0);
            dc.drawText(
                px,
                py,
                Graphics.FONT_TINY,
                average,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        } else {
            px = x(_boxLeft + _pad);
            dc.drawText(
                px,
                py,
                Graphics.FONT_TINY,
                average,
                Graphics.TEXT_JUSTIFY_LEFT
            );
        }
        return false;
    }

    // The main value of the current cell, vertically centred in its band.
    function drawCellValue(dc) {
        var font = fit(dc, _data[3], _valueRoom, _valueHeight);
        var py = y(_valueHeight) - dc.getFontHeight(font);
        py = y(_valueTop) + (py > 0 ? py / 2 : 0);
        if (_center) {
            dc.drawText(
                x(_boxLeft + _pad + _valueRoom / 2.0),
                py,
                font,
                _data[3],
                Graphics.TEXT_JUSTIFY_CENTER
            );
        } else {
            dc.drawText(
                x(_boxLeft + _pad),
                py,
                font,
                _data[3],
                Graphics.TEXT_JUSTIFY_LEFT
            );
        }
    }

    // One cell of a designed row, in the current box (246 x 322 units). The
    // work is split into small steps so that no single one holds much stack.
    function drawCell(dc) {
        _cellInk = _ink;
        if (_cell["zone"] == true) {
            drawZoneFill(dc);
        }
        // Short rows tuck the label closer to the top edge.
        var compact = _boxHeight < 70;
        _pad = _half ? 8 : 12;
        pickLabelFont(dc, _boxHeight);
        dc.setColor(_cellInk, Graphics.COLOR_TRANSPARENT);
        _valueRoom = _boxWidth - 2 * _pad;
        _valueTop = _boxTop + (compact ? 2 : 6);
        drawCellLabel(dc, _valueTop);
        _valueTop = _valueTop + pickLabelFont(dc, _boxHeight);
        _valueHeight = _boxTop + _boxHeight - _valueTop - (compact ? 2 : 6);
        if (_stats != null) {
            if (_half) {
                // Needs a row at least 80 px tall.
                if (_boxHeight >= 80 && drawHalfStats(dc)) {
                    return;
                }
            } else if (!compact) {
                // Needs a row at least 70 px tall.
                drawFullStats(dc);
            }
        }
        drawCellValue(dc);
    }

    function drawDesign(dc) {
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
        _center = DesignConfig.centered(config);
        var rows = config["rows"];
        for (var i = 0; i < rows.size(); i += 1) {
            var top = DesignConfig.rowTop(rows, i);
            var height = DesignConfig.rowTop(rows, i + 1) - top;
            var cells = rows[i]["cells"];
            var count = cells.size();
            _half = count > 1;
            for (var c = 0; c < count; c += 1) {
                _cell = cells[c];
                var id = _cell["metric"];
                _data = cellData(id);
                _stats = null;
                _boxLeft = DesignConfig.cellLeft(count, c);
                _boxWidth = DesignConfig.cellLeft(count, c + 1) - _boxLeft;
                _boxTop = top;
                _boxHeight = height;
                // The graph layout needs a full-width power or heart-rate
                // cell at least 75 px tall, and 110 px to also fit average
                // and maximum, which show unless switched off.
                if (
                    _cell["graph"] == true &&
                    !_half &&
                    height >= 75 &&
                    (id.equals("power") || id.equals("heartRate"))
                ) {
                    if (_cell["stats"] != false && height >= 110) {
                        _stats = cellStats(id);
                    }
                    drawGraphCell(
                        dc,
                        id.equals("power") ? _history : _heartHistory
                    );
                } else {
                    if (_cell["stats"] == true) {
                        _stats = cellStats(id);
                    }
                    drawCell(dc);
                }
            }
            // Dividers go on last so zone fills do not cover them.
            dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
            if (_half) {
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
