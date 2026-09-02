import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "volumio_ctrl"
  ipcTarget: "volumio_ctrl"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  property string activeButton: ""

  function flashButton(name) {
    activeButton = name
    flashTimer.restart()
  }

  function timeText(seconds) {
    var value = Math.max(0, Math.floor(Number(seconds) || 0))
    return Math.floor(value / 60) + ":" + (value % 60 < 10 ? "0" : "") + value % 60
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { if (root.service) root.service.discover() }
  }

  Timer {
    id: flashTimer
    interval: 50
    repeat: false
    onTriggered: root.activeButton = ""
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(520))
    contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(560))

    Column {
      id: content
      width: parent.width
      spacing: Style.space(14)

      Item {
        width: parent.width
        height: Style.space(190)

        Rectangle {
          id: cover
          width: Style.space(178)
          height: Style.space(178)
          color: Color.popups.background
          radius: Style.cornerRadius
          clip: true

          Image {
            anchors.fill: parent
            source: root.service && root.service.selectedHost && root.service.albumArt
              ? "http://" + root.service.selectedHost + ":3000" + root.service.albumArt
              : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
          }
          Text {
            anchors.centerIn: parent
            text: "♪"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.display
            visible: parent.children[0].status !== Image.Ready
          }
        }

        Column {
          anchors.left: cover.right
          anchors.leftMargin: Style.space(18)
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: Style.space(24)
          spacing: Style.space(5)

          Text {
            width: parent.width
            text: root.service && root.service.title ? root.service.title : "Loading Volumio"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: root.service ? root.service.artist : ""
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: root.service ? root.service.album : ""
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
        }

        Item {
          id: volumeCluster
          anchors.right: parent.right
          anchors.top: parent.top
          width: Style.space(112)
          height: Style.space(44)

          Canvas {
            id: volumeRing
            width: Style.space(44)
            height: Style.space(44)
            anchors.centerIn: parent
            onPaint: {
              var context = getContext("2d")
              var center = width / 2
              var radius = center - 4
              var value = root.service ? Math.max(0, Math.min(100, root.service.volume)) : 0
              context.reset()
              context.beginPath()
              context.arc(center, center, radius, 0, Math.PI * 2)
              context.strokeStyle = Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 2.5)
              context.lineWidth = 4
              context.stroke()
              context.beginPath()
              context.arc(center, center, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * value / 100)
              context.strokeStyle = Color.accent
              context.stroke()
            }
            Connections {
              target: root.service
              function onVolumeChanged() { volumeRing.requestPaint() }
            }
            Component.onCompleted: requestPaint()
          }
          Text {
            anchors.centerIn: volumeRing
            text: root.service ? Math.round(root.service.volume) : "-"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          TextButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            text: "-"
            onClicked: { root.flashButton("down"); if (root.service) root.service.volumeDown() }
          }
          TextButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            text: "+"
            onClicked: { root.flashButton("up"); if (root.service) root.service.volumeUp() }
          }
        }
      }

      Item {
        width: parent.width
        height: Style.space(28)
        Text {
          anchors.left: parent.left
          text: root.service ? root.timeText(root.service.seek) : "0:00"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text {
          anchors.right: parent.right
          text: root.service ? root.timeText(root.service.duration) : "0:00"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.space(5)
          color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 2.5)
          Rectangle {
            width: parent.width * (root.service && root.service.duration > 0 ? Math.min(1, root.service.seek / root.service.duration) : 0)
            height: parent.height
            color: Color.accent
          }
          MouseArea {
            anchors.fill: parent
            anchors.topMargin: -Style.space(8)
            anchors.bottomMargin: -Style.space(8)
            enabled: root.service && root.service.duration > 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
              if (!root.service || root.service.duration <= 0) return
              root.service.seekTo(root.service.duration * Math.max(0, Math.min(1, mouse.x / width)))
            }
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(10)
        TextButton { text: "PREV"; onClicked: { root.flashButton("previous"); if (root.service) root.service.previous() } }
        TextButton { text: root.service && root.service.isPlaying ? "PAUSE" : "PLAY"; onClicked: { root.flashButton("play"); if (root.service) root.service.playPause() } }
        TextButton { text: "NEXT"; onClicked: { root.flashButton("next"); if (root.service) root.service.next() } }
      }

      TextButton {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "SHUFFLE"
        selected: root.service && root.service.shuffle
        opacity: selected ? 1.0 : 0.45
        onClicked: { root.flashButton("shuffle"); if (root.service) root.service.toggleShuffle() }
      }
    }
  }

  component TextButton: Button {
    property bool compact: false
    width: compact ? Style.space(28) : implicitWidth + Style.space(18)
    height: compact ? Style.space(28) : Style.space(32)
    bordered: true
    background: Color.popups.background
    foreground: root.bar ? root.bar.foreground : Color.foreground
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    fontSize: Style.font.caption
  }
}
