import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MinimalFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MinimalFaceView()];
    }

    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
