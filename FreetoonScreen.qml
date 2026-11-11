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
		var checkFile = toonui_exists.read();
		app.freetoonExists = (checkFile.length > 0);
	}

	screenTitle: "Freetoon"

	Text {
		id: headline
		anchors {
			top: parent.top
			topMargin: isNxt ? 20 : 16
			left: parent.left
			leftMargin: isNxt ? 35 : 28
			right: parent.right
			rightMargin: anchors.leftMargin
		}
		color: colors.clockTileColor
		font {
			family: qfont.bold.name
			pixelSize: isNxt ? 30 : 24
		}
		wrapMode: Text.WordWrap
		text: "Welkom bij Freetoon, een snelle vervanging van de Eneco GUI"
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
		text: "Freetoon vervangt de trage Eneco QML appliatie met een snelle nieuwe gebruikers interface.\nMet name een Toon 1 zal veel sneller aanvoelen.\n" +
		      "De huidige thermostaat functie en het ingestelde programma blijven gewoon actief.\n" +
		      "Je kan Freetoon gewoon proberen en altijd terug naar de Eneco software via de tegel\n 'UI-Modus' in de Freetoon instellingen " +
		      "of door de Toon helemaal opnieuw te herstarten en dan 'Qt-Gui' te kiezen in het startup menu.\n" +
		      "Nadat je Freetoon voor de eerste keer hebt opgestart, ga dan naar instellingen (wieltje rechtsboven) " +
		      "en kies de tegel 'Scherm' voor algemene instellingen. Via de tegels 'Indeling' and 'Dim-Indeling' kan je de layout van je homescreen en gedimde scherm apart instellen."
	}

	StandardButton {
		id: goButton

		width: isNxt ? 260 : 180
		height: isNxt ? 64 : 50
		radius: 6
		anchors {
			top: intro.bottom
			topMargin: isNxt ? 28 : 22
			left: headline.left
		}
		Text {
			anchors.centerIn: parent
			text: app.freetoonExists ? "Start Freetoon" : "Install Freetoon"
			font {
				family: qfont.bold.name
				pixelSize: isNxt ? 24 : 18
			}
		}

		onClicked: {
			app.writeFiles();
			statusLine.text = app.freetoonExists ? "Freetoon wordt gestart... voortgang via 'Bekijk log'." : "Freetoon wordt geinstalleerd, even geduld... voortgang via 'Bekijk log'.";
			statusLine.visible = true;
			goButton.visible = false;
			uninstallButton.visible = false;
		}	
	}

	StandardButton {

		id: uninstallButton
		visible: app.freetoonExists

		width: isNxt ? 260 : 180
		height: isNxt ? 64 : 50
		radius: 6
		anchors {
			top: goButton.top
			left: goButton.right
			leftMargin: isNxt ? 20 : 16
		}

		Text {
			anchors.centerIn: parent
			text: "Uninstall Freetoon"
			font {
				family: qfont.bold.name
				pixelSize: isNxt ? 24 : 18
			}
		}

		onClicked: {
			app.uninstallFreeToon();
			statusLine.text = "Freetoon wordt verwijderd, even geduld... voortgang via 'Bekijk log'.";
			statusLine.visible = true;
			goButton.visible = false;
			uninstallButton.visible = false;
		}
	}

	Text {
		id: statusLine
		visible: false
		anchors {
			left: headline.left
			top: goButton.bottom
			topMargin: isNxt ? 16 : 12
			right: parent.right
		}
		font {
			family: qfont.semiBold.name
			pixelSize: isNxt ? 20 : 16
		}
		color: colors.clockTileColor

		wrapMode: Text.WordWrap
		text: ""
	}

	// ---- Log viewer --------------------------------------------------------
	// Stays visible after Install/Start/Uninstall so the progress can be followed,
	// and after a reboot to see why the switch failed (the log is on flash).

	property string logSource: "switch"     // "switch" | "launcher"

	StandardButton {
		id: logButton

		width: isNxt ? 200 : 150
		height: isNxt ? 64 : 50
		radius: 6
		anchors {
			top: goButton.top
			right: headline.right
		}
		Text {
			anchors.centerIn: parent
			text: "Bekijk log"
			font {
				family: qfont.bold.name
				pixelSize: isNxt ? 24 : 18
			}
		}
		onClicked: {
			logSource = "switch";
			refreshLog();
			logPanel.visible = true;
		}
	}

	function refreshLog() {
		logText.text = app.readLog(logSource, 300);
		// keep the newest lines in view
		logFlick.contentY = Math.max(0, logText.paintedHeight - logFlick.height);
	}

	Timer {
		id: logTimer
		interval: 2000
		repeat: true
		running: logPanel.visible
		onTriggered: {
			var atBottom = logFlick.contentY >= logText.paintedHeight - logFlick.height - 20;
			logText.text = app.readLog(logSource, 300);
			if (atBottom)       // don't yank the view away while someone scrolls back
				logFlick.contentY = Math.max(0, logText.paintedHeight - logFlick.height);
		}
	}

	Rectangle {
		id: logPanel
		visible: false
		z: 10
		color: "#ffffff"
		border.color: "#b0b0b0"
		border.width: 1
		radius: 6
		anchors {
			top: parent.top
			topMargin: isNxt ? 10 : 8
			bottom: parent.bottom
			bottomMargin: isNxt ? 10 : 8
			left: headline.left
			right: headline.right
		}

		Row {
			id: logTabs
			spacing: isNxt ? 12 : 10
			anchors {
				top: parent.top
				topMargin: isNxt ? 10 : 8
				left: parent.left
				leftMargin: isNxt ? 10 : 8
			}

			StandardButton {
				width: isNxt ? 230 : 175
				height: isNxt ? 50 : 40
				radius: 6
				Text {
					anchors.centerIn: parent
					text: (logSource === "switch" ? "> " : "") + "Installatie-log"
					font { family: qfont.bold.name; pixelSize: isNxt ? 20 : 16 }
				}
				onClicked: { logSource = "switch"; refreshLog(); }
			}
			StandardButton {
				width: isNxt ? 230 : 175
				height: isNxt ? 50 : 40
				radius: 6
				Text {
					anchors.centerIn: parent
					text: (logSource === "launcher" ? "> " : "") + "Launcher-log"
					font { family: qfont.bold.name; pixelSize: isNxt ? 20 : 16 }
				}
				onClicked: { logSource = "launcher"; refreshLog(); }
			}
		}

		StandardButton {
			id: logClose
			width: isNxt ? 140 : 110
			height: isNxt ? 50 : 40
			radius: 6
			anchors {
				top: logTabs.top
				right: parent.right
				rightMargin: isNxt ? 10 : 8
			}
			Text {
				anchors.centerIn: parent
				text: "Sluiten"
				font { family: qfont.bold.name; pixelSize: isNxt ? 20 : 16 }
			}
			onClicked: logPanel.visible = false
		}

		Flickable {
			id: logFlick
			clip: true
			anchors {
				top: logTabs.bottom
				topMargin: isNxt ? 10 : 8
				bottom: parent.bottom
				bottomMargin: isNxt ? 10 : 8
				left: parent.left
				leftMargin: isNxt ? 12 : 10
				right: parent.right
				rightMargin: isNxt ? 12 : 10
			}
			contentWidth: width
			contentHeight: logText.paintedHeight
			flickableDirection: Flickable.VerticalFlick

			Text {
				id: logText
				width: logFlick.width
				wrapMode: Text.WrapAnywhere
				color: "#202020"
				font {
					family: qfont.regular.name
					pixelSize: isNxt ? 15 : 12
				}
				text: ""
			}
		}
	}
}
