using Toybox.System;
using Toybox.UserProfile;
using Toybox.Activity;

class GarminZones {
    var heartRate = null;
    var power = null;
    // Zones worked out from Garmin's FTP, for when Garmin returns no zones.
    var powerFromFtp = null;
    // Rider weight from the Garmin profile, in grams, for watts per kilogram.
    var weightGrams = null;
    // What Garmin returned for power zones, for diagnosis: the raw limits
    // joined by "/", or "none", "unsupported" or "error".
    var powerRaw = "unread";
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

    function describe(boundaries) {
        if (boundaries == null) {
            return "none";
        }
        var text = boundaries.size().toString() + "-";
        for (var i = 0; i < boundaries.size(); i += 1) {
            text +=
                (i > 0 ? "/" : "") +
                (boundaries[i] == null ? "x" : boundaries[i].toString());
        }
        return text;
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
        // Garmin's call has been reported to return nothing on some Edges, so
        // ask under each sport the zones could be filed under and record
        // every answer for diagnosis.
        power = null;
        powerRaw = "";
        if (!(UserProfile has :getPowerZones)) {
            powerRaw = "unsupported";
        } else {
            var sports = [Activity.SPORT_CYCLING, Activity.SPORT_GENERIC];
            try {
                var profile =
                    Activity has :getProfileInfo
                        ? Activity.getProfileInfo()
                        : null;
                // Which sport the active Garmin profile reports.
                powerRaw +=
                    "profile:" +
                    (profile == null || profile.sport == null
                        ? "none"
                        : profile.sport.toString()) +
                    "|";
                if (
                    profile != null &&
                    profile.sport != null &&
                    profile.sport != Activity.SPORT_CYCLING &&
                    profile.sport != Activity.SPORT_GENERIC
                ) {
                    sports.add(profile.sport);
                }
            } catch (error) {
                powerRaw += "profile-error|";
            }
            for (var p = 0; p < sports.size(); p += 1) {
                var found = null;
                var answer = "error";
                try {
                    found = UserProfile.getPowerZones(sports[p]);
                    answer = describe(found);
                } catch (error) {
                    found = null;
                }
                powerRaw +=
                    (p > 0 ? "|" : "") +
                    "sport" +
                    sports[p].toString() +
                    ":" +
                    answer;
                if (
                    power == null &&
                    ZoneColors.valid(found) &&
                    found.size() == 8
                ) {
                    power = found;
                }
            }
        }
        try {
            var rider = UserProfile.getProfile();
            weightGrams = rider == null ? null : rider.weight;
        } catch (error) {
            weightGrams = null;
        }
        // Second choice: Garmin's FTP with Garmin's default zone percentages.
        powerFromFtp = null;
        try {
            if (UserProfile has :getFunctionalThresholdPower) {
                var ftp = UserProfile.getFunctionalThresholdPower(
                    Activity.SPORT_CYCLING
                );
                powerRaw += "|ftp:" + (ftp == null ? "none" : ftp.toString());
                powerFromFtp = ZoneColors.fromFtp(ftp);
            } else {
                powerRaw += "|ftp:unsupported";
            }
        } catch (error) {
            powerRaw += "|ftp:error";
        }
        if (!_reported) {
            logLimits("HR", heartRate);
            logLimits("power", power);
            _reported = true;
        }
    }
}
