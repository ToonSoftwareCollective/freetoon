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

	function safeRead(fileIO) {
		try {
			var t = fileIO.read();
			return t ? String(t) : "";
		} catch (e) {
			return "";
		}
	}

	// Last `maxLines` lines of the chosen log ("switch" or "launcher").
	function readLog(which, maxLines) {
		var txt;
		if (which === "launcher") {
			txt = safeRead(launcherLog);
			if (txt.length === 0)
				return "Geen launcher-log gevonden (/var/volatile/tmp/ui_launcher.log).\n" +
				       "Deze log bestaat alleen als Freetoon sinds de laatste herstart is opgestart.";
		} else {
			txt = safeRead(switchLogFlash);
			if (txt.length === 0)
				txt = safeRead(switchLogRam);
			if (txt.length === 0)
				return "Nog geen installatie-log gevonden.\n" +
				       "Druk op 'Install Freetoon' of 'Start Freetoon'; de voortgang verschijnt dan hier.";
		}
		var lines = txt.split("\n");
		if (lines.length > maxLines)
			lines = lines.slice(lines.length - maxLines);
		return lines.join("\n");
	}

	Timer {
		id: commandTimer
		interval: 150
		repeat: false
		property string commandText: ""
		onTriggered: {
			var f = new XMLHttpRequest();
			f.open("PUT", "file:///tmp/tsc.command");
			f.send(commandText);
		}
	}

	Component.onCompleted: {
		var checkFile = toonui_exists.read();
		freetoonExists = (checkFile.length > 0);
	}

	function writeFiles() {
		try {
			var g = new XMLHttpRequest();  //change default UI-choice into freetoon
			g.open("PUT", "file:///mnt/data/ui_choice");
			g.send("freetoon");
		} catch (e) {}

		// Decouple command write to /tmp/tsc.command via timer to prevent
		// concurrent XMLHttpRequest buffer collision and file write race conditions
		commandTimer.commandText = "external-freetoon\n";
		commandTimer.restart();
	}

	function uninstallFreeToon() {
		try {
			var a = new XMLHttpRequest();  //write action file for freetoon.sh
			a.open("PUT", "file:///tmp/freetoon.action");
			a.send("uninstall");
		} catch (e) {}

		// Decouple command write to /tmp/tsc.command via timer
		commandTimer.commandText = "external-freetoon\n";
		commandTimer.restart();
	}
	
	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("Freetoon"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", freetoonScreenUrl, this, null, {lazyLoadScreen: true});
	}
}
