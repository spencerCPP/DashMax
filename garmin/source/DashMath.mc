using Toybox.Math;

module DashMath {
    // Toybox.Math has no abs() function on the Edge 840 runtime.
    function absolute(value) {
        return value < 0 ? -value : value;
    }

    function headingDegrees(radians) {
        if (radians == null) {
            return null;
        }
        // Monkey C modulo only supports Number/Long, not floating-point angles.
        // Remove whole turns arithmetically to retain fractional degrees.
        var degrees = (radians * 180.0) / Math.PI;
        var turns = (degrees / 360.0).toNumber();
        degrees -= turns * 360.0;
        return degrees < 0 ? degrees + 360.0 : degrees;
    }

    function headingName(degrees) {
        if (degrees == null) {
            return "--";
        }
        var names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        var index = ((degrees + 22.5) / 45).toNumber() % 8;
        return names[index];
    }

    function convert(km, imperial) {
        return imperial ? km * 0.621371192 : km;
    }

    function distance(km, imperial) {
        var n = convert(km, imperial);
        return n >= 999.95 ? n.format("%.0f") : n.format("%.1f");
    }

    function elapsed(seconds) {
        var s = seconds.toNumber();
        var h = (s / 3600).toNumber();
        var m = ((s % 3600) / 60).toNumber();
        return (
            h.format("%d") +
            ":" +
            m.format("%02d") +
            ":" +
            (s % 60).format("%02d")
        );
    }

    // Percent with one decimal; never "-0.0".
    function grade(percent) {
        if (percent == null) {
            return "--";
        }
        return absolute(percent) < 0.05 ? "0.0" : percent.format("%.1f");
    }

    function ascent(metres, feet) {
        if (metres == null) {
            return "--";
        }
        return (feet ? metres * 3.280839895 : metres).format("%.0f");
    }

    function mockHeartRate(t) {
        return (150 + Math.sin(t * 0.05) * 18 + Math.sin(t * 0.31) * 3).toNumber();
    }

    function mockPower(t) {
        return (
            290 +
            Math.sin(t * 0.37) * 32 +
            Math.sin(t * 1.13) * 17 +
            Math.cos(t * 0.17) * 22
        ).toNumber();
    }
}
