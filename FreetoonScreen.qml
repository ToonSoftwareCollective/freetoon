import QtQuick 2.1
import qb.components 1.0
import FileIO 1.0

Screen {
	id: freetoonScreen

	FileIO {
		id: toonui_exists
		source: "file:///mnt/data/toonui"
 	}

	Component.onCompleted: {  //recheck current status

		var checkFile = app.toonui_exists.read();
		app.freetoonExists = (checkFile.length > 0)

	}

	screenTitle: "Freetoon"

	Text {
		id: headline
		anchors {
			top: parent.top
			topMargin: isNxt ? 30 : 24
			left: parent.left
			leftMargin: isNxt ? 60 : 48
			right: parent.right
			rightMargin: anchors.leftMargin
		}
		color: colors.clockTileColor
		font {
			family: qfont.bold.name
			pixelSize: isNxt ? 35 : 28
		}
		wrapMode: Text.WordWrap
		text: "Freetoon, a fast replacement for the Eneco GUI"
	}

	Text {
		id: intro
		anchors {
			top: headline.bottom
			topMargin: isNxt ? 18 : 14
			left: headline.left
			right: headline.right
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 21 : 17
		}
		lineHeight: 1.15
		color: colors.clockTileColor
		wrapMode: Text.WordWrap
		text: "Freetoon aims to 'free' the Toon from the cloggy Qt/QML interface and " +
		      "replaces it by a very fast 'C' application with rich functionality.\n" +
		      "Your current thermostat function will continue to work as is.\n" +
		      "You can always switch back from Freetoon to this QML interface by " +
		      "going to the Freetoon settings page and click the 'UI-modus' tile " +
		      "or by rebooting your Toon and select the Qt-Gui in the select Gui startup menu."
	}

	Rectangle {
		id: goButton

		width: isNxt ? 300 : 240
		height: isNxt ? 64 : 50
		radius: 6
		anchors {
			top: intro.bottom
			topMargin: isNxt ? 28 : 22
			left: headline.left
		}
		color: colors.clockTileColor
		Text {
			anchors.centerIn: parent
			text: app.freetoonExists ? "Start Freetoon" : "Install Freetoon"
			font {
				family: qfont.bold.name
				pixelSize: isNxt ? 28 : 22
			}
		}

		MouseArea {
			id: goArea
			anchors.fill: parent
			onClicked: {
				app.writeFile();
				statusLine.visible = true
				goButton.visible = false				
			}	
		}
	}

	Text {
		id: statusLine
		visible: false
		anchors {
			verticalCenter: goButton.verticalCenter
			left: goButton.left
			top: goButton.bottom
			topMargin: isNxt ? 12 : 9
			right: parent.right
		}
		font {
			family: qfont.semiBold.name
			pixelSize: isNxt ? 20 : 16
		}
		color: colors.clockTileColor

		wrapMode: Text.WordWrap
		text: app.freetoonExists ? "Starting Freetoon...... progress in /var/tmp/switch_to_freetoon.log" : "Installing Freetoon, please wait... progress in /var/tmp/switch_to_freetoon.log"
	}
}
