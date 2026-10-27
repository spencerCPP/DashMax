using Toybox.Test;

class PlaybackTestInfo {
    var currentPower = null;
    var averagePower = null;
    var currentHeartRate = null;
    var averageHeartRate = null;
    var currentCadence = null;
    var currentSpeed = null;
    var averageSpeed = null;
    var elapsedDistance = null;
    var elapsedTime = null;
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
    Test.assertEqual(ride.cadence, 0);
    Test.assertEqual(ride.power, null);
    Test.assertEqual(ride.averagePower, null);
    Test.assertEqual(ride.averageHeartRate, null);
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
    Test.assertEqual(ride.power, null);
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
