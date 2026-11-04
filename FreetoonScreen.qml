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
			statusLine.text = app.freetoonExists ? "Starting Freetoon...... progress in /var/volatile/tmp/switch_to_freetoon.log" : "Installing Freetoon, please wait... progress in /var/volatile/tmp/switch_to_freetoon.log";
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
			statusLine.text = "Uninstalling Freetoon, please wait... progress in /var/volatile/tmp/switch_to_freetoon.log";
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
}
