import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class MinimalFaceView extends WatchUi.WatchFace {

    private var _sleeping as Boolean = false;

    // private const TRACK = 0x1C1C1E;
    private const GRAY = 0x9A9AA2;
    private const OFF = 0x55555B;
    // private const NEON = 0x2BD9FF;
    private const LIGHT_GRAY = 0xECF0F1;
    private var _gs as Float = 1.0;
;


    function initialize() {
        WatchFace.initialize();
    }

    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        _gs = w / 454.0;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        if (!_sleeping && Application.Properties.getValue("BgGlow") == true) {
            drawHaze(dc, w, h);
        }

        var rx = (w * 0.603).toNumber();   // centre of the right-hand block

        drawDate(dc, rx, (h * 0.33).toNumber(), w, h);
        drawTime(dc, rx, (h * 0.485).toNumber(), w, h);

        // Always-on / low-power mode: time + date only
        if (_sleeping) {
            return;
        }

        drawBatteryRing(dc, w, h, System.getSystemStats().battery);
        drawSlots(dc, w, h);

        // row above the date (user-selectable)
        drawRow(dc, [prop("Top1", 8), prop("Top2", 9), prop("Top3", 10)], rx, (h * 0.215).toNumber(),
                (w * 0.026).toNumber(), (w * 0.032).toNumber(), (h * 0.05).toNumber());
        // row under the time (user-selectable)
        drawRow(dc, [prop("StatA", 2), prop("StatB", 1)], rx, (h * 0.645).toNumber(),
                (w * 0.028).toNumber(), (w * 0.07).toNumber(), (h * 0.056).toNumber());

        drawBottom(dc, rx, w, h);
    }

    // =====================================================
    //  Settings + fonts
    // =====================================================

    private function prop(key as String, def as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Number) {
            return v as Number;
        }
        return def;
    }

    // style: 0 = Garmin built-in, 1 = condensed bold, 2 = regular, 3 = condensed light
    private function faces(style as Number) as Array {
        if (style == 2) { return ["RobotoRegular", "BionicRegular", "Swiss721Regular"]; }
        if (style == 3) { return ["RobotoCondensedRegular", "RobotoRegular", "BionicRegular"]; }
        return ["RobotoCondensedBold", "BionicBold", "Swiss721Bold"];
    }

    // Largest vector font (<= startSize) in which txt fits maxW; otherwise `fallback`.
    private function pickFont(dc as Dc, txt as String, style as Number, startSize as Number,
                              maxW as Number, minSize as Number, fallback) {
        if (style == 0 || !(Graphics has :getVectorFont)) {
            return fallback;
        }
        var f = null;
        var size = startSize;
        while (size >= minSize) {
            f = Graphics.getVectorFont({:face => faces(style), :size => size});
            if (f == null) {
                return fallback;
            }
            if (dc.getTextWidthInPixels(txt, f) <= maxW) {
                return f;
            }
            size -= 2;
        }
        return (f != null) ? f : fallback;
    }

    private function textFont(dc as Dc, txt as String, size as Number, maxW as Number) {
        return pickFont(dc, txt, prop("TextFont", 1), size, maxW, 8, Graphics.FONT_XTINY);
    }

    private function timeFont(dc as Dc, txt as String, h as Number, maxW as Number) {
        var style = prop("TimeFont", 1);
        if (style != 0) {
            var f = pickFont(dc, txt, style, (h * 0.34).toNumber(), maxW, 24, null);
            if (f != null) {
                return f;
            }
        }
        var fonts = [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT,
                     Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD];
        for (var i = 0; i < 4; i++) {
            if (dc.getTextWidthInPixels(txt, fonts[i]) <= maxW) {
                return fonts[i];
            }
        }
        return fonts[3];
    }

    // =====================================================
    //  Date / time
    // =====================================================

    private function drawDate(dc as Dc, x as Number, y as Number, w as Number, h as Number) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var txt = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.day, info.month]).toUpper();
        var f = textFont(dc, txt, (h * 0.05).toNumber(), (w * 0.5).toNumber());
        dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, f, txt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawTime(dc as Dc, x as Number, y as Number, w as Number, h as Number) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var txt = Lang.format("$1$:$2$", [hour.format("%02d"), clock.min.format("%02d")]);
        var font = timeFont(dc, txt, h, (w * 0.67).toNumber());
        var just = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        if (_sleeping) {
            dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, font, txt, just);
        } 
        else {
            dc.setColor(LIGHT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, font, txt, just);
            
            // glowText(dc, x, y, font, txt, just, Graphics.COLOR_WHITE, NEON);
        }
    }

    // =====================================================
    //  Glow helpers (no real blur on Garmin -> layered, darkened copies)
    // =====================================================

    private function dim(c as Number, f as Float) as Number {
        var r = (((c >> 16) & 0xFF) * f).toNumber();
        var g = (((c >> 8) & 0xFF) * f).toNumber();
        var b = ((c & 0xFF) * f).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // glow width in px depending on screen size (min 1)
    private function gpx(v as Numeric) as Number {
        var r = (v * _gs).toNumber();
        return (r < 1) ? 1 : r;
    }

    // private function glowText(dc as Dc, x as Number, y as Number, font, txt as String,
    //                           just as Number, core as Number, glow as Number) as Void {
    //     var offs = [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]];
    //     var rad = [gpx(6), gpx(3)];
    //     var f = [0.12, 0.28];
    //     for (var a = 0; a < 2; a++) {
    //         dc.setColor(dim(glow, f[a]), Graphics.COLOR_TRANSPARENT);
    //         for (var i = 0; i < 8; i++) {
    //             dc.drawText(x + offs[i][0] * rad[a], y + offs[i][1] * rad[a], font, txt, just);
    //         }
    //     }
    //     dc.setColor(core, Graphics.COLOR_TRANSPARENT);
    //     dc.drawText(x, y, font, txt, just);
    // }

    private function drawProgressArc(dc as Dc, cx as Number, cy as Number, r as Number, p as Float) as Void {
        if (p <= 0.0) {
            return;
        }
        if (p >= 0.995) {
            dc.drawCircle(cx, cy, r);
            return;
        }
        var end = ((90 - (360.0 * p).toNumber()) % 360 + 360) % 360;
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, end);
    }

    private function glowArc(dc as Dc, cx as Number, cy as Number, r as Number, p as Float,
                             col as Number, pw as Number) as Void {
        if (p <= 0.0) {
            return;
        }
        var widths = [pw + gpx(10), pw + gpx(6), pw + gpx(3)];
        var f = [0.10, 0.20, 0.38];
        for (var i = 0; i < 3; i++) {
            dc.setPenWidth(widths[i]);
            dc.setColor(dim(col, f[i]), Graphics.COLOR_TRANSPARENT);
            drawProgressArc(dc, cx, cy, r, p);
        }
        dc.setPenWidth(pw);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        drawProgressArc(dc, cx, cy, r, p);
        dc.setPenWidth(1);
    }

    // Full thin ring in a dimmed version of the same colour + thick glowing progress arc.
    private function neonRing(dc as Dc, x as Number, y as Number, r as Number, p as Float,
                              col as Number, pw as Number) as Void {
        var tw = (pw * 0.4).toNumber();
        if (tw < 2) { tw = 2; }
        dc.setPenWidth(tw);
        dc.setColor(dim(col, 0.30), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, r);
        glowArc(dc, x, y, r, p, col, pw);
    }

    // =====================================================
    //  Battery ring
    // =====================================================

    private function batteryColor(pct as Float) as Number {
        if (pct <= 15.0) { return 0xFF2D55; }
        if (pct <= 30.0) { return 0xFF9F0A; }
        return 0x39FF8A;
    }

    private function drawBatteryRing(dc as Dc, w as Number, h as Number, pct as Float) as Void {
        neonRing(dc, w / 2, h / 2, w / 2 - 6, pct / 100.0, batteryColor(pct), 4);
    }

    // =====================================================
    //  Left side: 4 rings placed on an arc that follows the bezel.
    //  Outer two are larger, inner two smaller; values inside.
    // =====================================================

    // [x, y, r] of ring i (0 = top ... 3 = bottom)

        private function ringGeom(w as Number, h as Number, i as Number) as Array {
        var rc = w * 0.355;                 // radius of the arc the ring centres lie on
        var rOut = w * 0.1;
        var rIn = w * 0.08;
        var gap = w * 0.03;
        if (w <= 300) {                     // small screens (fenix 7 etc): 4 same rings
            rOut = w * 0.09;
            rIn = rOut;
            gap = w * 0.022;
        }
        var phi1 = Math.asin((2 * rIn + gap) / (2 * rc));
        var phi2 = phi1 + 2 * Math.asin((rIn + rOut + gap) / (2 * rc));
        var angs = [-phi2, -phi1, phi1, phi2];
        var rads = [rOut, rIn, rIn, rOut];
        var a = angs[i];
        return [(w / 2 - rc * Math.cos(a)).toNumber(),
                (h / 2 + rc * Math.sin(a)).toNumber(),
                rads[i].toNumber()];
    }

    private function slotId(i as Number) as Number {
        var keys = ["Slot1", "Slot2", "Slot3", "Slot4"];
        var id = prop(keys[i], i);
        if (id > 7 && id != 11) {
            id = 0;
        }
        return id;
    }

    // Faint colour haze behind the rings: concentric, very dark tints of each ring colour
    // (no alpha on Garmin, so outer layers are drawn first for all rings, then inner ones).
    private function drawHaze(dc as Dc, w as Number, h as Number) as Void {
        var mult = [2.5, 2.1, 1.7, 1.35, 0.9];
        var fs = [0.025, 0.045, 0.07, 0.10, 0.14];
        var cols = [];
        for (var i = 0; i < 4; i++) {
            cols.add(getMetric(slotId(i))[2]);
        }
        for (var k = 0; k < 5; k++) {
            for (var i = 0; i < 4; i++) {
                var g = ringGeom(w, h, i);
                dc.setColor(dim(cols[i] as Number, fs[k]), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(g[0], g[1], (g[2] * mult[k]).toNumber());
            }
        }
    }

    private function drawSlots(dc as Dc, w as Number, h as Number) as Void {
        for (var i = 0; i < 4; i++) {
            var g = ringGeom(w, h, i);
            var id = slotId(i);
            drawSlot(dc, g[0], g[1], g[2], id, getMetric(id));
        }
    }

    // Ring with the parameter icon on top and the value underneath.
    private function drawSlot(dc as Dc, x as Number, y as Number, r as Number, id as Number, m as Array) as Void {
        var prog = m[0] as Float;
        var txt = m[1] as String;
        var col = m[2] as Number;
        var pw = (r * 0.17).toNumber();
        if (pw < 3) { pw = 3; }

        neonRing(dc, x, y, r, prog, col, pw);

        var s = (r * 0.25).toNumber();
        if (s < 3) { s = 3; }
        drawIcon(dc, (id == 11) ? 14 : id, x, y - (r * 0.33).toNumber(), s, col);

        var f = textFont(dc, txt, (r * 0.56).toNumber(), (r * 1.3).toNumber());
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + (r * 0.31).toNumber(), f, txt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // [progress 0..1, text, colour]
    private function getMetric(id as Number) as Array {
        var info = ActivityMonitor.getInfo();
        if (id == 0) {                                   // Steps
            return [ratio(info.steps, info.stepGoal), compact(info.steps), 0x39FF8A];
        } else if (id == 1) {                            // Heart rate
            var hr = getHeartRate();
            if (hr == null) {
                return [0.0, "--", 0xFF2D6F];
            }
            return [ratio(hr, 180), hr.toString(), 0xFF2D6F];
        } else if (id == 2) {                            // Calories
            return [ratio(info.calories, 2500), compact(info.calories), 0xFF8A00];
        } else if (id == 3) {                            // Floors
            if ((info has :floorsClimbed) && info.floorsClimbed != null) {
                var goal = (info has :floorsClimbedGoal) ? info.floorsClimbedGoal : 10;
                return [ratio(info.floorsClimbed, goal), info.floorsClimbed.toString(), 0x2D9BFF];
            }
            return [0.0, "--", 0x2D9BFF];
        } else if (id == 4) {                            // Distance, km
            if (info.distance != null) {
                var km = info.distance / 100000.0;
                return [ratio(km, 8.0), km.format("%.1f"), 0x00E5FF];
            }
            return [0.0, "--", 0x00E5FF];
        } else if (id == 5) {                            // Active minutes (week)
            var am = info.activeMinutesWeek;
            if (am != null) {
                return [ratio(am.total, info.activeMinutesWeekGoal), compact(am.total), 0xFFE600];
            }
            return [0.0, "--", 0xFFE600];
        } else if (id == 6) {                            // Body Battery
            var bb = getBodyBattery();
            if (bb == null) {
                return [0.0, "--", 0xC45BFF];
            }
            return [ratio(bb, 100), bb.toString(), 0xC45BFF];
        } else if (id == 11) {                           // Battery
            var b = System.getSystemStats().battery;
            return [b / 100.0, b.toNumber().toString(), batteryColor(b)];
        } else {                                         // Temperature, °C
            var t = getTemperature();
            if (t == null) {
                return [0.0, "--", 0x7B6CFF];
            }
            return [ratio(t + 20, 60), t.toString() + "°", 0x7B6CFF];
        }
    }

    // =====================================================
    //  Generic row of items (icon + optional text), centred on cx.
    //  Ids: 0-7 metrics, 8 notifications, 9 bluetooth, 10 weather, 11 battery, 12 empty
    // =====================================================

    // returns [iconId, text or null, colour, weatherKind (-1 = not weather)]
    private function itemOf(id as Number) as Array {
        if (id == 8) {
            var n = System.getDeviceSettings().notificationCount;
            var hasNotifications = (n != null && n > 0);
            return [10, hasNotifications ? n.toString() : null, hasNotifications ? 0xFFFFFF : OFF, -1];
        }
        if (id == 9) {
            return [11, null, System.getDeviceSettings().phoneConnected ? 0x2D9BFF : OFF, -1];
        }
        if (id == 10) {
            var kind = 2;
            var txt = null;
            if ((Toybox has :Weather) && (Weather has :getCurrentConditions)) {
                var c = Weather.getCurrentConditions();
                if (c != null) {
                    kind = classify(c.condition);
                    if (c.temperature != null) {
                        txt = c.temperature.toNumber().toString() + "°";
                    }
                }
            }
            return [20, txt, 0xFFFFFF, kind];
        }
        if (id == 11) {
            var b = System.getSystemStats().battery;
            return [14, b.toNumber().toString() + "%", batteryColor(b), -1];
        }
        var m = getMetric(id);
        return [id, m[1], m[2], -1];
    }

    private function drawRow(dc as Dc, ids as Array, cx as Number, y as Number, s as Number,
                             gap as Number, size as Number) as Void {
        var items = [];
        var widths = [];
        var total = 0;

        for (var i = 0; i < ids.size(); i++) {
            if (ids[i] == 12) {
                continue;
            }
            var it = itemOf(ids[i] as Number);
            var txt = it[1];
            var tf = null;
            var wd = 2 * s;
            if (txt != null) {
                tf = textFont(dc, txt as String, size, s * 14);
                wd += 6 + dc.getTextWidthInPixels(txt as String, tf);
            }
            items.add([it, tf]);
            widths.add(wd);
            total += wd;
        }
        if (items.size() == 0) {
            return;
        }
        total += gap * (items.size() - 1);

        var x = cx - total / 2;
        for (var j = 0; j < items.size(); j++) {
            var it2 = items[j][0] as Array;
            var tf2 = items[j][1];
            if ((it2[3] as Number) >= 0) {
                drawWeatherIcon(dc, it2[3] as Number, x + s, y, s);
            } else {
                drawIcon(dc, it2[0] as Number, x + s, y, s, it2[2] as Number);
            }
            if (it2[1] != null) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x + 2 * s + 6, y, tf2, it2[1] as String,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            x += (widths[j] as Number) + gap;
        }
    }

    // Condition constants are numeric (Toybox.Weather.CONDITION_*)
    private function classify(c as Number or Null) as Number {
        if (c == null) { return 2; }
        if ([0, 23, 40].indexOf(c) >= 0) { return 0; }                                   // clear
        if ([1, 22, 52].indexOf(c) >= 0) { return 1; }                                   // partly cloudy
        if ([3, 11, 13, 14, 15, 24, 25, 26, 27, 31, 45, 49].indexOf(c) >= 0) { return 3; } // rain
        if ([4, 7, 16, 17, 18, 19, 21, 34, 43, 44, 46, 47, 48, 50, 51].indexOf(c) >= 0) { return 4; } // snow
        if ([6, 10, 12, 28].indexOf(c) >= 0) { return 5; }                               // storm
        if ([8, 9, 29, 30, 33, 35, 37, 38, 39].indexOf(c) >= 0) { return 6; }            // fog / haze
        return 2;                                                                        // cloudy
    }

    // =====================================================
    //  Bottom: chart or sunrise / sunset
    // =====================================================

    private function drawBottom(dc as Dc, rx as Number, w as Number, h as Number) as Void {
        var kind = prop("Chart", 0);
        if (kind == 5) {
            return;
        }
        if (kind == 4) {
            drawSunTimes(dc, rx, w, h);
        } else {
            var wd = (w * 0.40).toNumber();
            drawChart(dc, rx - wd / 2, (h * 0.70).toNumber(), wd, (h * 0.095).toNumber(), kind, h);
        }
    }

    private function readSeries(kind as Number) as Array {
        var out = [];
        if (!(Toybox has :SensorHistory)) {
            return out;
        }
        var dur = new Time.Duration(kind == 0 ? 10800 : 43200);
        var opts = {:period => dur, :order => SensorHistory.ORDER_OLDEST_FIRST};
        var it = null;

        if (kind == 0 && (SensorHistory has :getHeartRateHistory)) {
            it = SensorHistory.getHeartRateHistory(opts);
        } else if (kind == 1 && (SensorHistory has :getBodyBatteryHistory)) {
            it = SensorHistory.getBodyBatteryHistory(opts);
        } else if (kind == 2 && (SensorHistory has :getStressHistory)) {
            it = SensorHistory.getStressHistory(opts);
        } else if (kind == 3 && (SensorHistory has :getElevationHistory)) {
            it = SensorHistory.getElevationHistory(opts);
        }
        if (it == null) {
            return out;
        }

        var s = it.next();
        while (s != null) {
            if (s.data != null) {
                out.add(s.data.toFloat());
            }
            s = it.next();
        }
        return out;
    }

    private function drawChart(dc as Dc, x0 as Number, y0 as Number, wd as Number, ht as Number,
                               kind as Number, h as Number) as Void {
        var cols = [0xFF2D6F, 0xC45BFF, 0xFF8A00, 0x39FF8A];
        var col = cols[kind];
        var vals = readSeries(kind);
        var n = vals.size();

        dc.setPenWidth(1);
        dc.setColor(dim(col, 0.30), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x0, y0 + ht + 5, x0 + wd, y0 + ht + 5);

        if (n < 2) {
            var f = textFont(dc, "--", (h * 0.05).toNumber(), wd);
            dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x0 + wd / 2, y0 + ht / 2, f, "--",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var m = (n > 48) ? 48 : n;
        var lo = 0.0;
        var hi = 100.0;
        if (kind == 0 || kind == 3) {                      // auto-range for heart rate / elevation
            lo = vals[0];
            hi = vals[0];
            for (var i = 0; i < n; i++) {
                var v = vals[i];
                if (v < lo) { lo = v; }
                if (v > hi) { hi = v; }
            }
            if (hi - lo < 10.0) {
                hi = lo + 10.0;
            }
        }

        var px = new [m];
        var py = new [m];
        for (var i = 0; i < m; i++) {
            var idx = (i * (n - 1)) / (m - 1);
            var fr = (vals[idx] - lo) / (hi - lo);
            if (fr < 0.0) { fr = 0.0; }
            if (fr > 1.0) { fr = 1.0; }
            px[i] = x0 + (i * wd) / (m - 1);
            py[i] = y0 + ht - (fr * ht).toNumber();
        }

        var widths = [gpx(7), gpx(4)];
        var fs = [0.12, 0.30];
        for (var g = 0; g < 2; g++) {
            dc.setPenWidth(widths[g]);
            dc.setColor(dim(col, fs[g]), Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < m - 1; i++) {
                dc.drawLine(px[i], py[i], px[i + 1], py[i + 1]);
            }
        }
        dc.setPenWidth(2);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < m - 1; i++) {
            dc.drawLine(px[i], py[i], px[i + 1], py[i + 1]);
        }
        dc.fillCircle(px[m - 1], py[m - 1], 4);
        dc.setPenWidth(1);
    }

    private function fmtHM(hour as Number, min as Number) as String {
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        return hour.format("%02d") + ":" + min.format("%02d");
    }

    private function drawSunTimes(dc as Dc, rx as Number, w as Number, h as Number) as Void {
        var y = (h * 0.76).toNumber();
        var s = (w * 0.028).toNumber();
        var left = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var sr = "--:--";
        var ss = "--:--";

        if ((Toybox has :Weather) && (Weather has :getSunrise) && (Weather has :getCurrentConditions)) {
            var c = Weather.getCurrentConditions();
            if (c != null && (c has :observationLocationPosition) && c.observationLocationPosition != null) {
                var loc = c.observationLocationPosition;
                var now = Time.now();
                var a = Weather.getSunrise(loc, now);
                var b = Weather.getSunset(loc, now);
                if (a != null) {
                    var ia = Gregorian.info(a, Time.FORMAT_SHORT);
                    sr = fmtHM(ia.hour, ia.min);
                }
                if (b != null) {
                    var ib = Gregorian.info(b, Time.FORMAT_SHORT);
                    ss = fmtHM(ib.hour, ib.min);
                }
            }
        }

        var size = (h * 0.056).toNumber();
        var f1 = textFont(dc, sr, size, (w * 0.25).toNumber());
        var f2 = textFont(dc, ss, size, (w * 0.25).toNumber());
        var w1 = 2 * s + 6 + dc.getTextWidthInPixels(sr, f1);
        var w2 = 2 * s + 6 + dc.getTextWidthInPixels(ss, f2);
        var gap = (w * 0.06).toNumber();
        var x1 = rx - (w1 + gap + w2) / 2;
        var x2 = x1 + w1 + gap;

        drawIcon(dc, 12, x1 + s, y, s, 0xFFB000);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x1 + 2 * s + 6, y, f1, sr, left);

        drawIcon(dc, 13, x2 + s, y, s, 0xFF6A3D);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x2 + 2 * s + 6, y, f2, ss, left);
    }

    // =====================================================
    //  Data helpers
    // =====================================================

    private function ratio(v as Numeric or Null, g as Numeric or Null) as Float {
        if (v == null || g == null || g == 0) {
            return 0.0;
        }
        var r = v.toFloat() / g.toFloat();
        if (r < 0.0) { return 0.0; }
        return (r > 1.0) ? 1.0 : r;
    }

    private function compact(n as Numeric or Null) as String {
        if (n == null) {
            return "--";
        }
        if (n >= 10000) {
            return (n / 1000.0).format("%.1f") + "k";
        }
        return n.toNumber().toString();
    }

    private function getHeartRate() as Number or Null {
        var a = Activity.getActivityInfo();
        if (a != null && a.currentHeartRate != null) {
            return a.currentHeartRate;
        }
        var it = ActivityMonitor.getHeartRateHistory(1, true);
        var s = it.next();
        if (s != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            return s.heartRate;
        }
        return null;
    }

    private function getBodyBattery() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({:period => 1});
            if (it != null) {
                var s = it.next();
                if (s != null && s.data != null) {
                    return s.data.toNumber();
                }
            }
        }
        return null;
    }

    private function getTemperature() as Number or Null {
        if ((Toybox has :Weather) && (Weather has :getCurrentConditions)) {
            var c = Weather.getCurrentConditions();
            if (c != null && c.temperature != null) {
                return c.temperature.toNumber();
            }
        }
        return null;
    }

    // =====================================================
    //  Vector icons (no bitmaps needed). Grid is -10..10 units, scaled by s/10.
    // =====================================================

    private function u(c as Number, v as Numeric, k as Float) as Number {
        return (c + v * k).toNumber();
    }

    private function sz(v as Numeric, k as Float) as Number {
        var r = (v * k).toNumber();
        return (r < 1) ? 1 : r;
    }

    private function ln(dc as Dc, x as Number, y as Number, k as Float,
                        a as Numeric, b as Numeric, c as Numeric, d as Numeric) as Void {
        dc.drawLine(u(x, a, k), u(y, b, k), u(x, c, k), u(y, d, k));
    }

    private function poly(dc as Dc, x as Number, y as Number, k as Float, p as Array) as Void {
        var pts = [];
        for (var i = 0; i < p.size(); i += 2) {
            pts.add([u(x, p[i], k), u(y, p[i + 1], k)]);
        }
        dc.fillPolygon(pts);
    }

    // Fills a closed shape built from cubic Bezier segments.
    // p = [startX, startY, c1x, c1y, c2x, c2y, endX, endY, ...] in icon units.
    private function bezShape(dc as Dc, x as Number, y as Number, k as Float, p as Array) as Void {
        var px = (p[0] as Numeric).toFloat();
        var py = (p[1] as Numeric).toFloat();
        var pts = [[u(x, px, k), u(y, py, k)]];

        for (var i = 2; i + 5 < p.size(); i += 6) {
            var x1 = (p[i] as Numeric).toFloat();
            var y1 = (p[i + 1] as Numeric).toFloat();
            var x2 = (p[i + 2] as Numeric).toFloat();
            var y2 = (p[i + 3] as Numeric).toFloat();
            var x3 = (p[i + 4] as Numeric).toFloat();
            var y3 = (p[i + 5] as Numeric).toFloat();
            for (var j = 1; j <= 10; j++) {
                var t = j / 10.0;
                var m = 1.0 - t;
                var bx = m * m * m * px + 3 * m * m * t * x1 + 3 * m * t * t * x2 + t * t * t * x3;
                var by = m * m * m * py + 3 * m * m * t * y1 + 3 * m * t * t * y2 + t * t * t * y3;
                pts.add([u(x, bx, k), u(y, by, k)]);
            }
            px = x3;
            py = y3;
        }
        dc.fillPolygon(pts);
    }

    // Mix a colour towards white by fraction f (0..1).
    private function lighten(c as Number, f as Float) as Number {
        var r = (c >> 16) & 0xFF;
        var g = (c >> 8) & 0xFF;
        var b = c & 0xFF;
        r = (r + (255 - r) * f).toNumber();
        g = (g + (255 - g) * f).toNumber();
        b = (b + (255 - b) * f).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // ids: 0 steps, 1 heart, 2 flame, 3 stairs, 4 pin, 5 stopwatch, 6 bolt, 7 thermometer,
    //      10 envelope, 11 bluetooth, 12 sunrise, 13 sunset, 14 battery
    private function drawIcon(dc as Dc, id as Number, x as Number, y as Number, s as Number, col as Number) as Void {
        var k = s / 10.0;
        var pw = (k * 1.5).toNumber();
        if (pw < 1) { pw = 1; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pw);

        if (id == 0) {                                   // steps (two footprints)
            dc.fillEllipse(u(x, -4, k), u(y, 4, k), sz(3, k), sz(4.5, k));
            dc.fillCircle(u(x, -4, k), u(y, -2.5, k), sz(2, k));
            dc.fillEllipse(u(x, 4, k), u(y, -1, k), sz(3, k), sz(4.5, k));
            dc.fillCircle(u(x, 4, k), u(y, -7.5, k), sz(2, k));
        } else if (id == 1) {                            // heart
            dc.fillCircle(u(x, -4, k), u(y, -3, k), sz(4.5, k));
            dc.fillCircle(u(x, 4, k), u(y, -3, k), sz(4.5, k));
            poly(dc, x, y, k, [-8.2, -0.5, 8.2, 1, 1, 9.5]);
        } else if (id == 2) {                            // flame: smooth outline + lighter inner core
            bezShape(dc, x, y, k, [1, -10,
                3.2, -7.2, 7.4, -4.6, 7.6, 0.8,
                7.9, 6, 4.6, 10, 0, 10,
                -4.6, 10, -8, 6.6, -7.6, 1.6,
                -7.4, -1.2, -6.2, -3.4, -4.6, -5.4,
                -4.2, -3.6, -3.4, -2.8, -2.8, -1.8,
                -2.4, -5.2, 0.4, -6.6, 1, -10]);
            dc.setColor(lighten(col, 0.5), Graphics.COLOR_TRANSPARENT);
            bezShape(dc, x, y, k, [0.2, -1.4,
                2.2, 0.6, 4.2, 2.6, 3.8, 5.2,
                3.4, 7.6, 1.8, 8.4, 0, 8.4,
                -1.9, 8.4, -3.8, 7.1, -3.8, 4.8,
                -3.8, 2.6, -1.2, 1.6, 0.2, -1.4]);
        } else if (id == 3) {                            // stairs
            ln(dc, x, y, k, -9, 8, -3, 8);
            ln(dc, x, y, k, -3, 8, -3, 2);
            ln(dc, x, y, k, -3, 2, 3, 2);
            ln(dc, x, y, k, 3, 2, 3, -4);
            ln(dc, x, y, k, 3, -4, 9, -4);
        } else if (id == 4) {                            // location pin
            dc.fillCircle(x, u(y, -3, k), sz(6, k));
            poly(dc, x, y, k, [-5, 0, 5, 0, 0, 10]);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, u(y, -3, k), sz(2.2, k));
        } else if (id == 5) {                            // stopwatch
            dc.drawCircle(x, u(y, 1, k), sz(8, k));
            ln(dc, x, y, k, 0, 1, 0, -4);
            ln(dc, x, y, k, 0, 1, 4, 3);
            ln(dc, x, y, k, -2.5, -9.5, 2.5, -9.5);
        } else if (id == 6) {                            // lightning bolt
            poly(dc, x, y, k, [2, -10, -6, 2, -1, 2, -3, 10, 6, -3, 1, -3]);
        } else if (id == 7) {                            // thermometer
            dc.fillRoundedRectangle(u(x, -2, k), u(y, -9, k), sz(4, k), sz(13, k), sz(2, k));
            dc.fillCircle(x, u(y, 6, k), sz(4.5, k));
        } else if (id == 10) {                           // envelope
            dc.drawRectangle(u(x, -8, k), u(y, -5, k), sz(16, k), sz(11, k));
            ln(dc, x, y, k, -8, -5, 0, 2);
            ln(dc, x, y, k, 0, 2, 8, -5);
        } else if (id == 11) {                           // bluetooth
            ln(dc, x, y, k, -3.5, -6.5, 3.5, 3);
            ln(dc, x, y, k, 4.5, 3, 0, 8);
            ln(dc, x, y, k, 0, 8, 0, -8);
            ln(dc, x, y, k, 0, -8, 4.5, -3);
            ln(dc, x, y, k, 3.5, -3, -3.5, 6.5);
        } else if (id == 12 || id == 13) {               // sunrise / sunset
            dc.drawArc(x, u(y, 5, k), sz(6, k), Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
            ln(dc, x, y, k, -9, 5, 9, 5);
            ln(dc, x, y, k, 0, -9, 0, -3);
            if (id == 12) {
                ln(dc, x, y, k, -3, -6, 0, -9);
                ln(dc, x, y, k, 3, -6, 0, -9);
            } else {
                ln(dc, x, y, k, -3, -6, 0, -3);
                ln(dc, x, y, k, 3, -6, 0, -3);
            }
        } else if (id == 14) {                           // battery
            dc.drawRectangle(u(x, -9, k), u(y, -5, k), sz(16, k), sz(10, k));
            dc.fillRectangle(u(x, 7.5, k), u(y, -2, k), sz(2.5, k), sz(4, k));
            dc.fillRectangle(u(x, -7, k), u(y, -3, k), sz(10, k), sz(6, k));
        }
        dc.setPenWidth(1);
    }

    // ---- weather glyphs: 0 sun, 1 partly cloudy, 2 cloud, 3 rain, 4 snow, 5 storm, 6 fog ----

    private function sunShape(dc as Dc, x as Number, y as Number, k as Float) as Void {
        var d = [[1.0, 0.0], [0.7, 0.7], [0.0, 1.0], [-0.7, 0.7], [-1.0, 0.0], [-0.7, -0.7], [0.0, -1.0], [0.7, -0.7]];
        dc.setColor(0xFFD60A, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(sz(1.4, k));
        dc.fillCircle(x, y, sz(4, k));
        for (var i = 0; i < 8; i++) {
            dc.drawLine(u(x, d[i][0] * 6.5, k), u(y, d[i][1] * 6.5, k),
                        u(x, d[i][0] * 9.5, k), u(y, d[i][1] * 9.5, k));
        }
    }

    private function cloudShape(dc as Dc, x as Number, y as Number, k as Float, col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(u(x, -4, k), u(y, 1, k), sz(4, k));
        dc.fillCircle(u(x, 1, k), u(y, -1, k), sz(5, k));
        dc.fillCircle(u(x, 6, k), u(y, 2, k), sz(3.5, k));
        dc.fillRectangle(u(x, -4, k), u(y, 1, k), sz(10, k), sz(4, k));
    }

    private function drawWeatherIcon(dc as Dc, kind as Number, x as Number, y as Number, s as Number) as Void {
        var k = s / 10.0;
        var cloud = 0xB8C4D6;
        dc.setPenWidth(sz(1.5, k));

        if (kind == 0) {
            sunShape(dc, x, y, k);
        } else if (kind == 1) {
            sunShape(dc, u(x, -3, k), u(y, -3, k), k * 0.75);
            cloudShape(dc, u(x, 2, k), u(y, 3, k), k * 0.85, cloud);
        } else if (kind == 2) {
            cloudShape(dc, x, y, k, cloud);
        } else if (kind == 3) {
            cloudShape(dc, x, u(y, -3, k), k, cloud);
            dc.setColor(0x2D9BFF, Graphics.COLOR_TRANSPARENT);
            ln(dc, x, y, k, -3, 4, -4.5, 8);
            ln(dc, x, y, k, 1, 4, -0.5, 8);
            ln(dc, x, y, k, 5, 4, 3.5, 8);
        } else if (kind == 4) {
            cloudShape(dc, x, u(y, -3, k), k, cloud);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(u(x, -3, k), u(y, 6, k), sz(1.4, k));
            dc.fillCircle(u(x, 1, k), u(y, 8, k), sz(1.4, k));
            dc.fillCircle(u(x, 5, k), u(y, 6, k), sz(1.4, k));
        } else if (kind == 5) {
            cloudShape(dc, x, u(y, -3, k), k, 0x8892A6);
            dc.setColor(0xFFD60A, Graphics.COLOR_TRANSPARENT);
            poly(dc, x, y, k, [1.5, 2, -3, 7, 0, 7, -1.5, 11, 4, 5, 1, 5]);
        } else {
            dc.setColor(cloud, Graphics.COLOR_TRANSPARENT);
            ln(dc, x, y, k, -8, -5, 8, -5);
            ln(dc, x, y, k, -5, 0, 9, 0);
            ln(dc, x, y, k, -8, 5, 6, 5);
        }
        dc.setPenWidth(1);
    }
}
