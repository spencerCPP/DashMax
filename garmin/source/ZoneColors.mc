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

    // Palette is a presentation choice; boundaries always come from Garmin.
    // Return [background, use white foreground] for strong native contrast.
    function palette(zone, count) {
        if (zone == null || zone < 0 || zone >= count) {
            return null;
        }
        if (count == 5) {
            var colors = [
                [0xd8d8d8, false],
                [0x0066cc, true],
                [0x207020, true],
                [0xe0a020, false],
                [0xb02020, true],
            ];
            return colors[zone];
        }
        if (count == 7) {
            var colors = [
                [0xd8d8d8, false],
                [0x0066cc, true],
                [0x207020, true],
                [0xe0d040, false],
                [0xe09020, false],
                [0xb02020, true],
                [0x7030a0, true],
            ];
            return colors[zone];
        }
        return null;
    }
}
