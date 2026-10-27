using Toybox.Math;

module DashMath {
    function relativeFrom(course, from) {
        return ((((from - course + 180) % 360) + 360) % 360) - 180;
    }

    function component(relative, speed) {
        return speed * Math.cos((relative * Math.PI) / 180.0);
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
