using Toybox.Application;
using Toybox.WatchUi;

class DashMaxApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new DashMaxField()];
    }

    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
