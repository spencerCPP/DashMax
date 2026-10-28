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
