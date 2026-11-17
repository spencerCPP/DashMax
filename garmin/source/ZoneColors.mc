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

    // Seven power zones from FTP, using Garmin's default percentages: the top
    // of zones 1 to 6 is 55, 75, 90, 105, 120 and 150 percent of FTP. Returned
    // in Garmin's layout, [min zone 1, max zone 1, ... max zone 7], or null
    // without a usable FTP.
    function fromFtp(ftp) {
        if (ftp == null || ftp < 30 || ftp > 3000) {
            return null;
        }
        var percents = [55, 75, 90, 105, 120, 150];
        var bounds = [0];
        for (var i = 0; i < 6; i += 1) {
            bounds.add(((ftp * percents[i]) / 100.0 + 0.5).toNumber());
        }
        // Zone 7 has no upper limit.
        bounds.add(100000);
        return bounds;
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
