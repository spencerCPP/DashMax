using Toybox.Test;

function designRow(size, metrics) {
    var cells = [];
    for (var i = 0; i < metrics.size(); i += 1) {
        cells.add({ "metric" => metrics[i] });
    }
    return { "size" => size, "cells" => cells };
}

(:test)
function testRemoteDesignValidation(logger) {
    var config = {
        "version" => 2,
        "id" => "abcdef123456",
        "revision" => 1,
        "rows" => [
            designRow(3, ["power"]),
            designRow(1, ["graph"]),
            designRow(2, ["heartRate", "cadence"]),
            designRow(2, ["grade", "ascent"]),
        ],
        "background" => 0xffffff,
        "foreground" => 0,
    };
    Test.assert(DesignConfig.valid(config));
    Test.assert(!DesignConfig.valid(null));
    // Version 1 designs and unknown future versions are both refused.
    config["version"] = 1;
    Test.assert(!DesignConfig.valid(config));
    config["version"] = 3;
    Test.assert(!DesignConfig.valid(config));
    config["version"] = 2;
    config["background"] = -1;
    Test.assert(!DesignConfig.valid(config));
    config["background"] = 65279.5;
    Test.assert(!DesignConfig.valid(config));
    // JSON decoding produces separately allocated strings and numeric wrappers.
    config["background"] = 65279.0;
    config["foreground"] = 0.0;
    config["revision"] = 1l;
    config["version"] = 2.0;
    config["rows"] = [
        { "size" => 2.0, "cells" => [{ "metric" => "power ".substring(0, 5) }] },
    ];
    Test.assert(DesignConfig.valid(config));
    Test.assert(
        DesignConfig.sameString(
            "abcdef123456 ".substring(0, 12),
            "abcdef123456"
        )
    );
    config = DesignConfig.normalize(config);
    Test.assert(!DesignConfig.centered(config));
    config["align"] = "center ".substring(0, 6);
    Test.assert(DesignConfig.valid(config));
    Test.assert(DesignConfig.centered(config));
    config["align"] = "right";
    Test.assert(!DesignConfig.valid(config));
    config["align"] = "left";
    Test.assert(DesignConfig.valid(config));
    Test.assert(config["background"] instanceof Toybox.Lang.Number);
    Test.assert(config["rows"][0]["size"] instanceof Toybox.Lang.Number);
    return true;
}

(:test)
function testDesignRowRules(logger) {
    Test.assert(DesignConfig.rowsProblem([designRow(2, ["power"])]) == null);
    Test.assert(
        DesignConfig.rowsProblem([designRow(1, ["clock", "elapsed"])]) == null
    );
    Test.assert(DesignConfig.rowsProblem(null) != null);
    Test.assert(DesignConfig.rowsProblem([]) != null);
    Test.assert(DesignConfig.rowsProblem([designRow(4, ["power"])]) != null);
    Test.assert(DesignConfig.rowsProblem([designRow(1, [])]) != null);
    Test.assert(
        DesignConfig.rowsProblem([designRow(1, ["power", "speed", "grade"])]) !=
            null
    );
    Test.assert(DesignConfig.rowsProblem([designRow(1, ["wind"])]) != null);
    Test.assert(
        DesignConfig.rowsProblem([designRow(1, ["graph", "power"])]) != null
    );
    var seven = [];
    for (var i = 0; i < 7; i += 1) {
        seven.add(designRow(1, ["power"]));
    }
    Test.assert(DesignConfig.rowsProblem(seven) != null);
    // Equal rows are always fine; one small row beside three large is not.
    var large = [
        designRow(3, ["power"]),
        designRow(3, ["speed"]),
        designRow(3, ["grade"]),
    ];
    Test.assert(DesignConfig.rowsProblem(large) == null);
    large.add(designRow(1, ["ascent"]));
    Test.assert(DesignConfig.rowsProblem(large) != null);
    // Power zones carried by the design, in Garmin's eight-value layout.
    var zoned = { "powerZones" => [126, 167, 206, 236, 277, 342] };
    var bounds = DesignConfig.powerBounds(zoned);
    Test.assertEqual(bounds.size(), 8);
    Test.assertEqual(bounds[0], 0);
    Test.assertEqual(bounds[1], 126);
    Test.assertEqual(bounds[6], 342);
    Test.assertEqual(ZoneColors.index(126, bounds), 0);
    Test.assertEqual(ZoneColors.index(127, bounds), 1);
    Test.assertEqual(ZoneColors.index(267, bounds), 4);
    Test.assertEqual(ZoneColors.index(343, bounds), 6);
    Test.assertEqual(ZoneColors.index(2000, bounds), 6);
    Test.assert(DesignConfig.powerBounds({}) == null);
    zoned["powerZones"] = [126, 167, 206, 236, 277];
    Test.assert(DesignConfig.powerBounds(zoned) == null);
    zoned["powerZones"] = [126, 167, 206, 236, 277, 277];
    Test.assert(DesignConfig.powerBounds(zoned) == null);
    // Same boxes as layout() in shared/design.test.mjs.
    var rows = [
        designRow(3, ["power"]),
        designRow(1, ["graph"]),
        designRow(2, ["heartRate", "cadence"]),
        designRow(2, ["speed", "distance"]),
    ];
    Test.assertEqual(DesignConfig.rowTop(rows, 0), 0);
    Test.assertEqual(DesignConfig.rowTop(rows, 1), 120);
    Test.assertEqual(DesignConfig.rowTop(rows, 2), 161);
    Test.assertEqual(DesignConfig.rowTop(rows, 3), 241);
    Test.assertEqual(DesignConfig.rowTop(rows, 4), 322);
    Test.assertEqual(DesignConfig.cellLeft(2, 1), 123);
    Test.assertEqual(DesignConfig.cellLeft(2, 2), 246);
    Test.assertEqual(DesignConfig.cellLeft(1, 1), 246);
    return true;
}

(:test)
function testSyncPacing(logger) {
    // Slow by default, fast for three minutes after a change arrives.
    Test.assertEqual(SyncPace.interval(100, null), 10);
    Test.assertEqual(SyncPace.interval(100, 100), 5);
    Test.assertEqual(SyncPace.interval(280, 100), 5);
    Test.assertEqual(SyncPace.interval(281, 100), 10);
    Test.assertEqual(SyncPace.interval(50, 100), 10);
    // First attempt is immediate, then at the current interval.
    Test.assert(SyncPace.due(100, null, 30));
    Test.assert(!SyncPace.due(129, 100, 30));
    Test.assert(SyncPace.due(130, 100, 30));
    Test.assert(!SyncPace.due(104, 100, 5));
    Test.assert(SyncPace.due(105, 100, 5));
    // A wrapped timer must not block the next attempt.
    Test.assert(SyncPace.due(3, 100, 30));
    // Sync is allowed only when no ride is in progress; paused still counts.
    Test.assert(!SyncPace.riding(null));
    Test.assert(!SyncPace.riding(Toybox.Activity.TIMER_STATE_OFF));
    Test.assert(SyncPace.riding(Toybox.Activity.TIMER_STATE_ON));
    Test.assert(SyncPace.riding(Toybox.Activity.TIMER_STATE_PAUSED));
    Test.assert(SyncPace.riding(Toybox.Activity.TIMER_STATE_STOPPED));
    return true;
}
