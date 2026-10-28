import QtQuick 2.1
//import qb.base 1.0
import qb.components 1.0

Tile {
	id: freetoonTile

	onClicked: stage.openFullscreen(app.freetoonScreenUrl)


	Text {
		id: txtFreetoonStatus
		text: "Freetoon"
		anchors {
			baseline: parent.top
			baselineOffset: isNxt ? 70 : 55
			left: parent.left
			leftMargin: app.leftMarginTime
		}
		font.pixelSize: isNxt ? 65 : 50
		font.family: qfont.regular.name
	}
}
