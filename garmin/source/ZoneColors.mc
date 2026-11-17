// Garmin limits are [min zone 1, max zone 1, max zone 2, ... max zone N].
// Keep unavailable, invalid, and below-zone readings on the host background.
module ZoneColors {
    function valid(boundaries) {
        if (boundaries == null || boundaries.size() < 2) {
            return false;
        }
        for (var i = 0; i < boundaries.size(); i += 1) {
            if (boundaries[i] == null || boundaries[i] < 0) {
                return false;
            }
            if (i > 0 && boundaries[i] <= boundaries[i - 1]) {
                return false;
            }
        }
        return true;
    }

    function index(value, boundaries) {
        if (
            value == null ||
            value <= 0 ||
            !valid(boundaries) ||
            value < boundaries[0]
        ) {
            return null;
        }
        for (var i = 1; i < boundaries.size(); i += 1) {
            if (value <= boundaries[i]) {
                return i - 1;
            }
        }
        return boundaries.size() - 2;
    }

    // Seven power zones from FTP. The top of zones 1 to 6 is 55.5, 73.6, 90.7,
    // 104.0, 122.0 and 150.7 percent of FTP: the ratios between a rider's
    // Garmin Connect zone limits (126/167/206/236/277/342 W) and their FTP
    // (227 W), which these figures reproduce exactly. Returned
    // in Garmin's layout, [min zone 1, max zone 1, ... max zone 7], or null
    // without a usable FTP.
    function fromFtp(ftp) {
        if (ftp == null || ftp < 30 || ftp > 3000) {
            return null;
        }
        var perMille = [555, 736, 907, 1040, 1220, 1507];
        var bounds = [0];
        for (var i = 0; i < 6; i += 1) {
            bounds.add(((ftp * perMille[i]) / 1000.0 + 0.5).toNumber());
        }
        // Zone 7 has no upper limit.
        bounds.add(100000);
        return bounds;
    }

    // Colour for a road grade in percent, using the bands Garmin's ClimbPro
    // page draws: up to 3 green, 6 yellow, 9 orange, 12 red, steeper dark red.
    // An exact band top stays in the lower band. Flat and downhill are left
    // uncoloured. Colours are sampled from Garmin's own climb-category
    // swatches. Returns [background, use white foreground] or null.
    function grade(percent) {
        if (percent == null || percent <= 0) {
            return null;
        }
        if (percent <= 3) {
            return [0x7dbb56, false];
        }
        if (percent <= 6) {
            return [0xefad43, false];
        }
        if (percent <= 9) {
            return [0xdf6336, false];
        }
        if (percent <= 12) {
            return [0xda3a32, true];
        }
        return [0x75140c, true];
    }

    // Garmin reference colors supplied by the user; limits come from Garmin APIs.
    // Return [background, use white foreground] for strong native contrast.
    function palette(zone, count) {
        if (zone == null || zone < 0 || zone >= count) {
            return null;
        }
        if (count == 5) {
            var colors = [
                [0xa6a6a6, false],
                [0x3b97f3, false],
                [0x40c35d, false],
                [0xf27716, false],
                [0xe02c2c, true],
            ];
            return colors[zone];
        }
        if (count == 7) {
            var colors = [
                [0xa6a6a6, false],
                [0x3b97f3, false],
                [0x40c35d, false],
                [0xfaca48, false],
                [0xf27716, false],
                [0xe02c2c, true],
                [0x6f42f3, true],
            ];
            return colors[zone];
        }
        return null;
    }
}
