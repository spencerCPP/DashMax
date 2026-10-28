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
    return true;
}
