using Toybox.Test;

class PlaybackTestInfo {
    var currentPower = null;
    var averagePower = null;
    var currentHeartRate = null;
    var averageHeartRate = null;
    var currentCadence = null;
    var currentHeading = null;
    var currentSpeed = null;
    var averageSpeed = null;
    var elapsedDistance = null;
    var elapsedTime = null;
    var altitude = null;
    var totalAscent = null;
    var maxPower = null;
    var maxHeartRate = null;
    var maxSpeed = null;
    var averageCadence = null;
    var maxCadence = null;
    function initialize() {}
}

(:test)
function testPlaybackUnitsAndMissingData(logger) {
    var ride = new ActivityRide();
    var info = new PlaybackTestInfo();
    info.currentSpeed = 10.0;
    info.averageSpeed = 5.0;
    info.elapsedDistance = 142700.0;
    info.elapsedTime = 38184000;
    info.currentHeartRate = 158;
    info.currentCadence = 0;
    Test.assert(ride.update(info, 0));
    Test.assert(DashMath.absolute(ride.speedKmh - 36.0) < 0.001);
    Test.assert(DashMath.absolute(ride.averageSpeedKmh - 18.0) < 0.001);
    Test.assert(DashMath.absolute(ride.distanceKm - 142.7) < 0.001);
    Test.assertEqual(ride.elapsedSeconds, 38184);
    Test.assertEqual(ride.heartRate, 158);
    Test.assertEqual(ride.cadence, 0.0);
    Test.assert(ride.power == null);
    Test.assert(ride.averagePower == null);
    Test.assert(ride.averageHeartRate == null);
    // Ride maximums and average cadence, for the avg/max column.
    Test.assert(ride.maxPower == null);
    Test.assert(ride.maxCadence == null);
    info.maxPower = 612;
    info.maxHeartRate = 171;
    info.maxSpeed = 15.0;
    info.averageCadence = 88;
    info.maxCadence = 118;
    info.elapsedTime = 38185000;
    ride.update(info, 0);
    Test.assertEqual(ride.maxPower, 612);
    Test.assertEqual(ride.maxHeartRate, 171);
    Test.assert(DashMath.absolute(ride.maxSpeedKmh - 54.0) < 0.001);
    Test.assertEqual(ride.averageCadence, 88.0);
    Test.assertEqual(ride.maxCadence, 118.0);
    ride.cadenceDivisor = 2;
    info.elapsedTime = 38186000;
    ride.update(info, 0);
    Test.assertEqual(ride.maxCadence, 59.0);
    return true;
}

(:test)
function testPlaybackThreeSecondPower(logger) {
    var ride = new ActivityRide();
    var info = new PlaybackTestInfo();
    info.elapsedTime = 1000;
    info.currentPower = 100;
    ride.update(info, 0);
    info.elapsedTime = 2000;
    info.currentPower = 200;
    ride.update(info, 0);
    info.elapsedTime = 3000;
    info.currentPower = 300;
    ride.update(info, 0);
    Test.assert(DashMath.absolute(ride.power - 200.0) < 0.001);
    Test.assert(!ride.update(info, 0));
    info.elapsedTime = 4000;
    info.currentPower = 0;
    ride.update(info, 0);
    Test.assert(DashMath.absolute(ride.power - 500.0 / 3) < 0.001);
    info.elapsedTime = 5000;
    info.currentPower = null;
    ride.update(info, 0);
    Test.assert(ride.power == null);
    return true;
}

(:test)
function testPlaybackSeekResetsWindow(logger) {
    var ride = new ActivityRide();
    var info = new PlaybackTestInfo();
    info.elapsedTime = 10000;
    info.currentPower = 500;
    ride.update(info, 0);
    info.elapsedTime = 1000;
    info.currentPower = 100;
    ride.update(info, 0);
    Test.assert(ride.resetHistory);
    Test.assert(DashMath.absolute(ride.power - 100.0) < 0.001);
    info.elapsedTime = 20000;
    info.currentPower = 200;
    ride.update(info, 0);
    Test.assert(ride.resetHistory);
    Test.assert(DashMath.absolute(ride.power - 200.0) < 0.001);
    return true;
}

(:test)
function testExplicitReplayCadenceCorrection(logger) {
    var ride = new ActivityRide();
    var info = new PlaybackTestInfo();
    info.elapsedTime = 1000;
    info.currentCadence = 86;
    ride.update(info, 0);
    Test.assertEqual(ride.cadence, 86.0);
    // Even unusually high cadence is preserved in ordinary activity mode.
    info.currentCadence = 172;
    ride.update(info, 0);
    Test.assertEqual(ride.cadence, 172.0);
    ride.cadenceDivisor = 2;
    ride.update(info, 0);
    Test.assertEqual(ride.cadence, 86.0);
    info.currentCadence = 192;
    ride.update(info, 0);
    Test.assertEqual(ride.cadence, 96.0);
    info.currentCadence = 0;
    ride.update(info, 0);
    Test.assertEqual(ride.cadence, 0.0);
    info.currentCadence = null;
    ride.update(info, 0);
    Test.assert(ride.cadence == null);
    return true;
}

(:test)
function testActivityHeadingRequiresMovingGpsCourse(logger) {
    var ride = new ActivityRide();
    var info = new PlaybackTestInfo();
    info.currentSpeed = 5.0;
    info.currentHeading = 1.57079632679;
    ride.update(info, 1);
    Test.assert(DashMath.absolute(ride.headingDegrees - 90) < 0.001);
    info.currentSpeed = 0.0;
    ride.update(info, 2);
    Test.assert(ride.headingDegrees == null);
    info.currentSpeed = 5.0;
    info.currentHeading = null;
    ride.update(info, 3);
    Test.assert(ride.headingDegrees == null);
    return true;
}

(:test)
function testGradeAndAscent(logger) {
    var ride = new ActivityRide();
    var info = new PlaybackTestInfo();
    info.elapsedTime = 1000;
    info.elapsedDistance = 0.0;
    info.altitude = 100.0;
    info.totalAscent = 486.0;
    ride.update(info, 0);
    // One sample is not a slope.
    Test.assert(ride.grade == null);
    Test.assertEqual(ride.ascentM, 486.0);
    info.elapsedTime = 2000;
    info.elapsedDistance = 50.0;
    info.altitude = 102.5;
    ride.update(info, 0);
    Test.assert(DashMath.absolute(ride.grade - 5.0) < 0.001);
    // Measured from the oldest sample in the window, so descents show too.
    info.elapsedTime = 3000;
    info.elapsedDistance = 100.0;
    info.altitude = 97.0;
    ride.update(info, 0);
    Test.assert(DashMath.absolute(ride.grade + 3.0) < 0.001);
    // Barely moving: too little distance to trust.
    var slow = new ActivityRide();
    info.elapsedTime = 1000;
    info.elapsedDistance = 0.0;
    slow.update(info, 0);
    info.elapsedTime = 2000;
    info.elapsedDistance = 2.0;
    slow.update(info, 0);
    Test.assert(slow.grade == null);
    // No altitude source.
    info.elapsedTime = 3000;
    info.elapsedDistance = 60.0;
    info.altitude = null;
    info.totalAscent = null;
    slow.update(info, 0);
    Test.assert(slow.grade == null);
    Test.assert(slow.ascentM == null);
    Test.assertEqual(DashMath.grade(null), "--");
    Test.assertEqual(DashMath.grade(-0.04), "0.0");
    Test.assertEqual(DashMath.grade(-3.26), "-3.3");
    Test.assertEqual(DashMath.ascent(486.0, false), "486");
    Test.assertEqual(DashMath.ascent(100.0, true), "328");
    Test.assertEqual(DashMath.ascent(null, true), "--");
    return true;
}
