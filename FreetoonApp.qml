import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0;
import FileIO 1.0

App {
	id: tscClockApp

	// These are the URL's for the QML resources from which our widgets will be instantiated.
	// By making them a URL type property they will automatically be converted to full paths,
	// preventing problems when passing them around to code that comes from a different path.

	property url tileUrl : "FreetoonTile.qml";
	property url freetoonScreenUrl: "FreetoonScreen.qml"
	property url thumbnailIcon: "qrc:/tsc/refresh.png"
	property bool freetoonExists : false

	property alias toonui_exists: toonui_exists

	FileIO {
		id: toonui_exists
		source: "file:///mnt/data/toonui"
 	}

	FileIO {
		id: ui_choice
		source: "file:///mnt/data/ui_choice"
 	}

	// Logs for the "Bekijk log" view. freetoon.sh >= 1.0.6 keeps the switch log on
	// flash (survives a reboot); older versions only wrote the RAM copy.
	FileIO {
		id: switchLogFlash
		source: "file:///mnt/data/switch_to_freetoon.log"
	}
	FileIO {
		id: switchLogRam
		source: "file:///var/volatile/tmp/switch_to_freetoon.log"
	}
	FileIO {
		id: launcherLog
		source: "file:///var/volatile/tmp/ui_launcher.log"
	}
	// TSC's command file, shared by all ToonStore apps.
	FileIO {
		id: tscCommand
		source: "file:///var/volatile/tmp/tsc.command"
	}

	function safeRead(fileIO) {
		try {
			var t = fileIO.read();
			return t ? String(t) : "";
		} catch (e) {
			return "";
		}
	}

	function switchLogText() {
		var txt = safeRead(switchLogFlash);
		if (txt.length === 0)
			txt = safeRead(switchLogRam);
		return txt;
	}

	// Last `maxLines` lines of the chosen log ("switch" or "launcher").
	// After Start/Install/Uninstall the switch log shows only the current run,
	// so an old "launch initiated successfully" can't be mistaken for this one.
	function readLog(which, maxLines) {
		var txt;
		if (which === "launcher") {
			txt = safeRead(launcherLog);
			if (txt.length === 0)
				return "Geen launcher-log gevonden (/var/volatile/tmp/ui_launcher.log).\n" +
				       "Deze log bestaat alleen als Freetoon sinds de laatste herstart is opgestart.";
		} else {
			txt = switchLogText();
			if (actionKind !== "") {
				if (!scriptStarted())
					return "Wachten tot ToonStore (TSC) het Freetoon-script start...\n\n" + actionStatus;
				var i = txt.lastIndexOf(markerText);
				if (i >= 0)
					txt = txt.substring(txt.lastIndexOf("\n", i) + 1);
			}
			if (txt.length === 0)
				return "Nog geen installatie-log gevonden.\n" +
				       "Druk op 'Install Freetoon' of 'Start Freetoon'; de voortgang verschijnt dan hier.";
		}
		var lines = txt.split("\n");
		if (lines.length > maxLines)
			lines = lines.slice(lines.length - maxLines);
		return lines.join("\n");
	}

	Component.onCompleted: {
		var checkFile = toonui_exists.read();
		freetoonExists = (checkFile.length > 0);
	}

	// ---- Start / Install / Uninstall via TSC, with a watchdog ---------------
	// The button can't run freetoon.sh itself: it writes "external-freetoon" to
	// /var/volatile/tmp/tsc.command (= TSC's /tmp/tsc.command; /tmp is a symlink
	// that is broken on some Toons, so never use /tmp) and TSC runs the script
	// on its next round. TSC deletes
	// that file after EVERY command it handles, so a request written while TSC
	// is busy with another app's command (seen: a PostNL login of ~47 s) is
	// thrown away and nothing happens. The watchdog below checks that the
	// script really started (a new "Starting FreeToon" line in the switch log)
	// and offers the command again if it was lost.
	property string markerText: "[freetoon] Starting FreeToon"
	property string actionKind: ""        // "", "start", "install", "uninstall"
	property string actionStatus: ""
	property bool actionBusy: false        // waiting for the script to start
	property bool actionFailed: false      // gave up: buttons come back
	property string markerBefore: ""       // last start line before the press
	property bool needWrite: false         // command still to be written
	property int watchTicks: 0
	property int goneTicks: 0
	property int attempts: 0

	// Full log line (with timestamp) of the last "Starting FreeToon ..." entry.
	function lastStartMarker(txt) {
		var i = txt.lastIndexOf(markerText);
		if (i < 0)
			return "";
		var e = txt.indexOf("\n", i);
		return txt.substring(txt.lastIndexOf("\n", i) + 1, e < 0 ? txt.length : e);
	}

	function scriptStarted() {
		var m = lastStartMarker(switchLogText());
		return m.length > 0 && m !== markerBefore;
	}

	function actionLabel() {
		if (actionKind === "uninstall") return "Freetoon wordt verwijderd.";
		if (actionKind === "install")   return "Freetoon wordt geinstalleerd.";
		return "Freetoon wordt gestart.";
	}

	// Write the command, but only into an empty command file: another app's
	// pending command (e.g. PostNL) is never overwritten.
	function writeCommand() {
		if (safeRead(tscCommand).replace(/\s/g, "").length > 0) {
			needWrite = true;
			return;
		}
		needWrite = false;
		attempts++;
		try {
			if (actionKind === "uninstall") {
				var a = new XMLHttpRequest();  // action file for freetoon.sh
				a.open("PUT", "file:///var/volatile/tmp/freetoon.action");
				a.send("uninstall");
			}
			var f = new XMLHttpRequest();
			f.open("PUT", "file:///var/volatile/tmp/tsc.command");
			f.send("external-freetoon\n");
		} catch (e) {}
	}

	function beginAction(kind) {
		actionKind = kind;
		actionFailed = false;
		actionBusy = true;
		markerBefore = lastStartMarker(switchLogText());
		watchTicks = 0;
		goneTicks = 0;
		attempts = 0;
		if (kind !== "uninstall") {
			try {
				var g = new XMLHttpRequest();  // default UI choice -> freetoon
				g.open("PUT", "file:///mnt/data/ui_choice");
				g.send("freetoon");
			} catch (e) {}
		}
		actionStatus = actionLabel() + " Wachten tot ToonStore (TSC) het script start...";
		writeCommand();
		watchTimer.restart();
	}

	Timer {
		id: watchTimer
		interval: 5000          // TSC handles its command file every ~5 s when idle
		repeat: true
		onTriggered: {
			watchTicks++;
			if (scriptStarted()) {
				stop();
				actionBusy = false;
				actionStatus = actionLabel() + " Het script draait; volg de voortgang via 'Bekijk log'.";
				return;
			}
			var cmd = safeRead(tscCommand);
			if (cmd.indexOf("external-freetoon") >= 0) {
				goneTicks = 0;          // still queued: TSC is busy with something else
			} else if (cmd.replace(/\s/g, "").length > 0) {
				goneTicks = 0;          // another app's command waits: don't touch it
				needWrite = true;
			} else if (needWrite) {
				writeCommand();         // file free again: our first/next write
			} else {
				// Gone without a start line. TSC starts the script before it deletes
				// the file, so give it one more round before offering it again.
				goneTicks++;
				if (goneTicks >= 2) {
					goneTicks = 0;
					writeCommand();
					console.log("[freetoon] tsc.command was dropped; offered again (attempt " + attempts + ")");
				}
			}
			if (watchTicks >= 36) {     // 3 minutes
				stop();
				actionBusy = false;
				actionFailed = true;
				actionStatus = "ToonStore (TSC) heeft het Freetoon-script na 3 minuten nog niet gestart. " +
				               "Probeer het opnieuw; blijft dit gebeuren, herstart dan de Toon.";
				return;
			}
			actionStatus = actionLabel() + " Wachten tot ToonStore (TSC) het script start... (" +
			               (watchTicks * 5) + " s" + (attempts > 1 ? ", opnieuw aangeboden" : "") + ")";
		}
	}
	
	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("Freetoon"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", freetoonScreenUrl, this, null, {lazyLoadScreen: true});
	}
}
