using Toybox.Test;
using Toybox.Math;

(:test)
function testHeadingDirections(logger) {
    Test.assertEqual(DashMath.headingDegrees(null), null);
    Test.assert(
        DashMath.absolute(DashMath.headingDegrees(Math.PI / 2) - 90) < 0.001
    );
    Test.assert(
        DashMath.absolute(DashMath.headingDegrees(-Math.PI / 2) - 270) < 0.001
    );
    Test.assert(
        DashMath.absolute(
            DashMath.headingDegrees((25.25 * Math.PI) / 180.0) - 25.25
        ) < 0.001
    );
    Test.assert(
        DashMath.absolute(
            DashMath.headingDegrees((-1.25 * Math.PI) / 180.0) - 358.75
        ) < 0.001
    );
    Test.assert(
        DashMath.absolute(
            DashMath.headingDegrees((725.5 * Math.PI) / 180.0) - 5.5
        ) < 0.001
    );
    Test.assertEqual(DashMath.headingName(null), "--");
    Test.assertEqual(DashMath.headingName(0), "N");
    Test.assertEqual(DashMath.headingName(45), "NE");
    Test.assertEqual(DashMath.headingName(90), "E");
    Test.assertEqual(DashMath.headingName(180), "S");
    Test.assertEqual(DashMath.headingName(359.9), "N");
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
