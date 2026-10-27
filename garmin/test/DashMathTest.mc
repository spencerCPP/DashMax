using Toybox.Test;

(:test)
function testWindDirections(logger) {
    Test.assertEqual(DashMath.absolute(-12), 12);
    Test.assertEqual(DashMath.absolute(12), 12);
    Test.assertEqual(DashMath.absolute(0), 0);
    Test.assertEqual(DashMath.relativeFrom(359, 1), 2);
    Test.assertEqual(DashMath.relativeFrom(90, 0), -90);
    Test.assertEqual(DashMath.relativeFrom(270, 0), 90);
    Test.assert(DashMath.absolute(DashMath.component(0, 12) - 12) < 0.001);
    Test.assert(DashMath.absolute(DashMath.component(180, 12) + 12) < 0.001);
    Test.assert(DashMath.absolute(DashMath.component(90, 12)) < 0.001);
    Test.assert(DashMath.absolute(DashMath.component(48.19, 12) - 8) < 0.01);
    return true;
}

(:test)
function testLongRideFormatting(logger) {
    Test.assert(
        DashMath.absolute(DashMath.convert(36.0, true) - 22.369362912) < 0.001
    );
    Test.assertEqual(DashMath.convert(36.0, false), 36.0);
    Test.assertEqual(DashMath.distance(1.609344, true), "1.0");
    Test.assertEqual(DashMath.elapsed(38184), "10:36:24");
    Test.assertEqual(DashMath.elapsed(86400), "24:00:00");
    Test.assertEqual(DashMath.distance(999.9, false), "999.9");
    Test.assertEqual(DashMath.distance(1000.0, false), "1000");
    Test.assertEqual(DashMath.distance(1609.344, true), "1000");
    return true;
}
