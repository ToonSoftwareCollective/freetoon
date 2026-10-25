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


	FileIO {
		id: toonui_exists
		source: "file:///mnt/data/toonui"
 	}

	Component.onCompleted: {

		var checkFile = toonui_exists.read();
		freetoonExists = (checkFile.length > 0)
	}

	function writeFile() {
		var f = new XMLHttpRequest();
		f.open("PUT", "file:///tmp/tsc.command");
		f.send("external-freetoon");
	}
	
	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("Freetoon"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", freetoonScreenUrl, this, null, {lazyLoadScreen: true});
	}
}



