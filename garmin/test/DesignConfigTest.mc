using Toybox.Test;

(:test)
function testRemoteDesignValidation(logger) {
    var config = {
        "version" => 1,
        "id" => "abcdef123456",
        "revision" => 1,
        "fields" => ["power", "heartRate", "distance"],
        "background" => 0xffffff,
        "foreground" => 0,
    };
    Test.assert(DesignConfig.valid(config));
    config["fields"] = ["power", "power", "distance"];
    Test.assert(!DesignConfig.valid(config));
    config["fields"] = ["power", "cadence", "elapsed"];
    Test.assert(DesignConfig.valid(config));
    config["fields"] = ["power", "cadence", "unknown"];
    Test.assert(!DesignConfig.valid(config));
    config["fields"] = ["power", "cadence", "elapsed"];
    config["version"] = 2;
    Test.assert(!DesignConfig.valid(config));
    config["version"] = 1;
    config["background"] = -1;
    Test.assert(!DesignConfig.valid(config));
    Test.assert(!DesignConfig.valid(null));
    // JSON decoding produces separately allocated strings and numeric wrappers.
    config["background"] = 65279.0;
    config["foreground"] = 0.0;
    config["revision"] = 1l;
    config["version"] = 1.0;
    config["fields"] = [
        "power ".substring(0, 5),
        "heartRate ".substring(0, 9),
        "speed ".substring(0, 5),
    ];
    Test.assert(DesignConfig.valid(config));
    Test.assert(
        DesignConfig.sameString(
            "abcdef123456 ".substring(0, 12),
            "abcdef123456"
        )
    );
    config = DesignConfig.normalize(config);
    Test.assert(config["background"] instanceof Toybox.Lang.Number);
    config["background"] = 65279.5;
    Test.assert(!DesignConfig.valid(config));
    config["background"] = 65279;
    config["fields"] = [
        "power ".substring(0, 5),
        "power__".substring(0, 5),
        "speed",
    ];
    Test.assert(!DesignConfig.valid(config));
    return true;
}
