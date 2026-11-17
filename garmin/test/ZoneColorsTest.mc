using Toybox.Test;

(:test)
function testGarminZoneBoundaries(logger) {
    var hr = [100, 120, 140, 160, 180, 200];
    Test.assert(ZoneColors.index(null, hr) == null);
    Test.assert(ZoneColors.index(0, hr) == null);
    Test.assert(ZoneColors.index(99, hr) == null);
    Test.assertEqual(ZoneColors.index(100, hr), 0);
    Test.assertEqual(ZoneColors.index(119, hr), 0);
    Test.assertEqual(ZoneColors.index(120, hr), 0);
    Test.assertEqual(ZoneColors.index(180, hr), 3);
    Test.assertEqual(ZoneColors.index(121, hr), 1);
    Test.assertEqual(ZoneColors.index(181, hr), 4);
    Test.assertEqual(ZoneColors.index(200, hr), 4);
    Test.assertEqual(ZoneColors.index(210, hr), 4);
    var power = [0, 100, 150, 200, 250, 300, 350, 1000];
    Test.assertEqual(ZoneColors.index(100, power), 0);
    Test.assertEqual(ZoneColors.index(100.1, power), 1);
    Test.assertEqual(ZoneColors.index(350, power), 5);
    Test.assertEqual(ZoneColors.index(351, power), 6);
    // A changed Garmin threshold must change classification, not just metadata.
    Test.assertEqual(ZoneColors.index(125, [100, 130, 150, 170, 190, 210]), 0);
    Test.assertEqual(ZoneColors.index(125, hr), 1);
    return true;
}

(:test)
function testUnavailableZonesStayNeutral(logger) {
    Test.assert(ZoneColors.index(150, null) == null);
    Test.assert(ZoneColors.index(150, []) == null);
    Test.assert(ZoneColors.index(150, [100, 100, 150]) == null);
    Test.assert(ZoneColors.index(150, [100, null, 200]) == null);
    Test.assert(ZoneColors.palette(null, 5) == null);
    Test.assert(ZoneColors.palette(0, 4) == null);
    Test.assert(ZoneColors.palette(7, 7) == null);
    Test.assert(ZoneColors.palette(0, 5) != null);
    Test.assert(ZoneColors.palette(6, 7) != null);
    return true;
}

class ZoneDrawingRecorder {
    var rectangles;
    function initialize() {
        rectangles = [];
    }
    function setColor(foreground, background) {}
    function fillRectangle(left, top, width, height) {
        rectangles.add([left, top, width, height]);
    }
}

(:test)
function testOnlyPowerAndHeartRateRegionsAreFilled(logger) {
    var field = new DashMaxField();
    var dc = new ZoneDrawingRecorder();
    var boundaries = [100, 120, 140, 160, 180, 200];
    field.zoneBackground(dc, 150, boundaries, 0, 127);
    field.zoneBackground(dc, 170, boundaries, 128, 65);
    Test.assertEqual(dc.rectangles.size(), 2);
    Test.assertEqual(dc.rectangles[0][0], 0);
    Test.assertEqual(dc.rectangles[0][1], 0);
    Test.assertEqual(dc.rectangles[0][2], 246);
    Test.assertEqual(dc.rectangles[0][3], 127);
    Test.assertEqual(dc.rectangles[1][1], 128);
    Test.assertEqual(dc.rectangles[1][3], 65);
    field.zoneBackground(dc, null, boundaries, 0, 127);
    Test.assertEqual(dc.rectangles.size(), 2);
    return true;
}

(:test)
function testPowerZonesFromFtp(logger) {
    // The reference rider: 227 W FTP gives their Garmin Connect limits.
    var bounds = ZoneColors.fromFtp(227);
    Test.assertEqual(bounds.size(), 8);
    Test.assertEqual(bounds[0], 0);
    Test.assertEqual(bounds[1], 126);
    Test.assertEqual(bounds[2], 167);
    Test.assertEqual(bounds[3], 206);
    Test.assertEqual(bounds[4], 236);
    Test.assertEqual(bounds[5], 277);
    Test.assertEqual(bounds[6], 342);
    Test.assert(ZoneColors.valid(bounds));
    Test.assertEqual(ZoneColors.index(126, bounds), 0);
    Test.assertEqual(ZoneColors.index(127, bounds), 1);
    Test.assertEqual(ZoneColors.index(343, bounds), 6);
    // Limits scale with FTP and round to the nearest watt; decimals are fine.
    Test.assertEqual(ZoneColors.fromFtp(300)[1], 167);
    Test.assertEqual(ZoneColors.fromFtp(300)[6], 452);
    Test.assertEqual(ZoneColors.fromFtp(227.0)[4], 236);
    Test.assert(ZoneColors.fromFtp(null) == null);
    Test.assert(ZoneColors.fromFtp(0) == null);
    return true;
}
