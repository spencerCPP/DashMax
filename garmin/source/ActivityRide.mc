// Reads the activity values supplied by Garmin, including simulator FIT playback.
// Optional/missing channels remain null. No mock or lap averages are substituted.
class ActivityRide {
    var power = null;
    var averagePower = null;
    var heartRate = null;
    var averageHeartRate = null;
    var headingDegrees = null;
    var cadence = null;
    // Explicit replay workaround only; ordinary activity data uses divisor 1.
    var cadenceDivisor = 1;
    var speedKmh = null;
    var averageSpeedKmh = null;
    var distanceKm = null;
    var elapsedSeconds = null;
    var resetHistory = false;
    var _powers;
    var _times;
    var _head = 0;
    var _clock = null;

    function initialize() {
        _powers = new [3];
        _times = new [3];
    }

    function update(info, fallbackClock) {
        averagePower = info has :averagePower ? info.averagePower : null;
        heartRate = info has :currentHeartRate ? info.currentHeartRate : null;
        averageHeartRate =
            info has :averageHeartRate ? info.averageHeartRate : null;
        var rawCadence = info has :currentCadence ? info.currentCadence : null;
        cadence =
            rawCadence == null ? null : rawCadence / (cadenceDivisor * 1.0);
        var course = info has :currentHeading ? info.currentHeading : null;
        var speed = info has :currentSpeed ? info.currentSpeed : null;
        var averageSpeed = info has :averageSpeed ? info.averageSpeed : null;
        var distance = info has :elapsedDistance ? info.elapsedDistance : null;
        var elapsed = info has :elapsedTime ? info.elapsedTime : null;
        headingDegrees =
            speed == null || speed < 1.0
                ? null
                : DashMath.headingDegrees(course);
        speedKmh = speed == null ? null : speed * 3.6;
        averageSpeedKmh = averageSpeed == null ? null : averageSpeed * 3.6;
        distanceKm = distance == null ? null : distance / 1000.0;
        elapsedSeconds = elapsed == null ? null : (elapsed / 1000).toNumber();
        // Prefer activity time so FIT seeks/restarts reset the smoothing window.
        var clock = elapsedSeconds == null ? fallbackClock : elapsedSeconds;
        var current = info has :currentPower ? info.currentPower : null;
        resetHistory = false;
        if (_clock != null && clock == _clock) {
            if (current == null) {
                power = null;
            }
            return false;
        }
        if (_clock != null && (clock < _clock || clock > _clock + 3)) {
            _powers = new [3];
            _times = new [3];
            _head = 0;
            resetHistory = true;
        }
        _clock = clock;
        _powers[_head] = current;
        _times[_head] = clock;
        _head = (_head + 1) % 3;
        // A missing current sensor reading must not display an old power value.
        power = null;
        if (current != null) {
            var total = 0.0;
            var count = 0;
            for (var i = 0; i < 3; i += 1) {
                if (
                    _powers[i] != null &&
                    _times[i] != null &&
                    clock - _times[i] < 3
                ) {
                    total += _powers[i];
                    count += 1;
                }
            }
            power = total / count;
        }
        return true;
    }
}
