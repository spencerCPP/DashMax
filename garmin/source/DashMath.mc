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
        return ((((radians * 180.0) / Math.PI) % 360) + 360) % 360;
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

    function mockPower(t) {
        return (
            290 +
            Math.sin(t * 0.37) * 32 +
            Math.sin(t * 1.13) * 17 +
            Math.cos(t * 0.17) * 22
        ).toNumber();
    }
}
