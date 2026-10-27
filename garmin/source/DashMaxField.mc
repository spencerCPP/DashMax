using Toybox.Application;
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

// Select mock telemetry or host Activity.Info (including simulator FIT playback).
// No real weather source is configured.
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

    function initialize() {
        DataField.initialize();
        _ride = new ActivityRide();
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

    function setting(name) {
        return Application.Properties.getValue(name);
    }

    function compute(info) {
        var now = (System.getTimer() / 1000).toNumber();
        var activity = setting("ActivityData") == true;
        if (activity != _activity) {
            _activity = activity;
            _ride = new ActivityRide();
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
        var font = Graphics.FONT_XTINY;
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
                font = candidate;
                break;
            }
        }
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

    function onUpdate(dc) {
        _width = dc.getWidth();
        _height = dc.getHeight();
        var dark = setting("Dark");
        var imperial = setting("Imperial");
        var activity = setting("ActivityData") == true;
        var missing = activity
            ? _ride.power == null
            : setting("SensorState") == 1;
        var stopped = !activity && setting("SensorState") == 2;
        var animate = !activity && setting("Animate");
        var bg = dark ? 0x182820 : 0xf4f4e9;
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
        drawWind(dc, imperial);
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

    function drawWind(dc, imperial) {
        var scenario =
            setting("ActivityData") == true ? 5 : setting("WindScenario");
        var relative = 48.19;
        if (scenario == 1) {
            relative = 0.0;
        }
        if (scenario == 2) {
            relative = 180.0;
        }
        if (scenario == 3) {
            relative = -90.0;
        }
        if (scenario == 4) {
            relative = 90.0;
        }
        label(
            dc,
            scenario == 6 ? "STALE WIND" : "EST WIND",
            12,
            266,
            81,
            false
        );
        if (scenario == 5) {
            text(dc, "--", 12, 283, 76, 22, _ink, false);
            label(dc, "NO DATA", 12, 306, 81, false);
            return;
        }
        var c = DashMath.component(
            relative,
            DashMath.convert(19.312128, imperial)
        );
        var radians = (relative * Math.PI) / 180.0;
        dc.setColor(_line, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x(23), y(293), x(10));
        dc.setColor(_ink, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x(23), y(298), x(23), y(287));
        dc.drawLine(x(23), y(287), x(20), y(290));
        dc.drawLine(x(23), y(287), x(26), y(290));
        dc.setColor(_accent, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(
            x(23 + 10 * Math.sin(radians)),
            y(293 - 10 * Math.cos(radians)),
            2
        );
        text(
            dc,
            DashMath.convert(19.312128, imperial).format("%.0f"),
            38,
            282,
            24,
            23,
            _ink,
            false
        );
        label(dc, imperial ? "mph" : "km/h", 65, 289, 28, false);
        var absoluteComponent = DashMath.absolute(c);
        var direction =
            absoluteComponent < 0.1 ? "CROSS" : c > 0 ? "HEAD" : "TAIL";
        var magnitude = absoluteComponent.format("%.0f");
        label(
            dc,
            direction == "CROSS" ? direction : magnitude + " " + direction,
            12,
            306,
            81,
            false
        );
    }
}
