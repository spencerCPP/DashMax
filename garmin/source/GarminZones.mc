using Toybox.System;
using Toybox.UserProfile;
using Toybox.Activity;

class GarminZones {
    var heartRate = null;
    var power = null;
    var _refreshedAt = null;
    var _reported = false;

    function initialize() {}

    function logLimits(name, boundaries) {
        if (boundaries == null) {
            System.println("Garmin cycling " + name + " zones unavailable");
            return;
        }
        System.println(
            "Garmin cycling " + name + " limits (min Z1, max Z1, ...):"
        );
        for (var i = 0; i < boundaries.size(); i += 1) {
            System.println(
                "  [" + i.toString() + "] " + boundaries[i].toString()
            );
        }
    }

    function refresh() {
        var now = (System.getTimer() / 1000).toNumber();
        if (
            _refreshedAt != null &&
            now >= _refreshedAt &&
            now - _refreshedAt < 10
        ) {
            return;
        }
        _refreshedAt = now;
        try {
            var hrBounds =
                UserProfile has :getHeartRateZones2
                    ? UserProfile.getHeartRateZones2(Activity.SPORT_CYCLING)
                    : UserProfile.getHeartRateZones(
                          UserProfile.HR_ZONE_SPORT_BIKING
                      );
            heartRate =
                ZoneColors.valid(hrBounds) && hrBounds.size() == 6
                    ? hrBounds
                    : null;
        } catch (error) {
            heartRate = null;
        }
        try {
            // The SDK exposes cycling power-zone limits directly. Never derive
            // stand-in thresholds from generic FTP percentages.
            var powerBounds =
                UserProfile has :getPowerZones
                    ? UserProfile.getPowerZones(Activity.SPORT_CYCLING)
                    : null;
            power =
                ZoneColors.valid(powerBounds) && powerBounds.size() == 8
                    ? powerBounds
                    : null;
            if (!_reported && powerBounds != null && power == null) {
                System.println(
                    "Power zone format needs verification; leaving power background neutral."
                );
                logLimits("power (raw)", powerBounds);
            }
        } catch (error) {
            power = null;
        }
        if (!_reported) {
            logLimits("HR", heartRate);
            logLimits("power", power);
            _reported = true;
        }
    }
}
