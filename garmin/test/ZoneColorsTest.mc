using Toybox.Test;

(:test)
function testGarminZoneBoundaries(logger) {
    var hr = [100, 120, 140, 160, 180, 200];
    Test.assertEqual(ZoneColors.index(null, hr), null);
    Test.assertEqual(ZoneColors.index(0, hr), null);
    Test.assertEqual(ZoneColors.index(99, hr), null);
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
    Test.assertEqual(ZoneColors.index(150, null), null);
    Test.assertEqual(ZoneColors.index(150, []), null);
    Test.assertEqual(ZoneColors.index(150, [100, 100, 150]), null);
    Test.assertEqual(ZoneColors.index(150, [100, null, 200]), null);
    Test.assertEqual(ZoneColors.palette(null, 5), null);
    Test.assertEqual(ZoneColors.palette(0, 4), null);
    Test.assertEqual(ZoneColors.palette(7, 7), null);
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
