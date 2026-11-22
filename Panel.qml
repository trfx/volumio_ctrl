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
  property bool playlistOpen: false
  property bool musicOpen: false

  onPlaylistOpenChanged: if (playlistOpen) Qt.callLater(root.positionCurrentTrack)

  function showMainInterface() {
    root.musicOpen = false
    root.playlistOpen = false
    if (root.bar && root.hostWidget && root.bar.activePopout === root.hostWidget)
      root.bar.releasePopout(root.hostWidget)
    root.controller.hide()
    Qt.callLater(function() { root.controller.show() })
  }

  function escapeFromMenu() {
    root.showMainInterface()
  }

  function closeAll() {
    root.musicOpen = false
    root.playlistOpen = false
    root.close()
  }

  function flashButton(name) {
    activeButton = name
    flashTimer.restart()
  }

  function timeText(seconds) {
    var value = Math.max(0, Math.floor(Number(seconds) || 0))
    return Math.floor(value / 60) + ":" + (value % 60 < 10 ? "0" : "") + value % 60
  }

  function selectedTrackForeground() {
    var luminance = 0.2126 * Color.accent.r + 0.7152 * Color.accent.g + 0.0722 * Color.accent.b
    return luminance > 0.5 ? "#111111" : "#ffffff"
  }

  function apiIconGlyph(icon, title) {
    var glyphs = {
      "fa fa-music": "\uf001",
      "fa fa-heartbeat": "\uf21e",
      "fa fa-heart": "\uf004",
      "fa fa-star": "\uf005",
      "fa fa-tags": "\uf02c",
      "fa fa-map-marker": "\uf041",
      "fa fa-globe": "\uf0ac",
      "fa fa-thumbs-o-up": "\uf087",
      "fa fa-diamond": "\uf219"
    }
    if (String(title || "") === "Volumio Selection") return glyphs["fa fa-music"]
    return glyphs[String(icon || "")] || ""
  }

  function isMusicLibraryView() {
    return root.service && root.service.browseLibraryView === true
  }

  function albumArtUrl() {
    if (!root.service || !root.service.albumArt) return ""
    var art = root.service.albumArt
    if (/^https?:\/\//.test(art)) return art
    return "http://" + root.service.selectedHost + ":3000" + (art.charAt(0) === "/" ? art : "/" + art)
  }

  function positionCurrentTrack() {
    if (!root.service || !playlistView.count) return
    var currentUri = root.service.currentUri
    var queue = root.service.queue || []
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].uri === currentUri) {
        playlistView.positionViewAtIndex(i, ListView.Contain)
        return
      }
    }
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
    id: musicPopup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.musicOpen
    contentWidth: musicPopup.fittedContentWidth(Style.space(620))
    contentHeight: musicPopup.fittedContentHeight(musicContent.implicitHeight, Style.space(620))
    focusTarget: musicKeys

    Column {
      id: musicContent
      width: parent.width
      spacing: Style.space(10)

      Row {
        width: parent.width
        spacing: Style.space(8)
        TextButton {
          text: "BACK"
          compact: true
          onClicked: {
            if (root.service && (root.service.browseUri !== ""
                || root.service.browseHistory.length > 0)) {
              root.service.goBackBrowse()
            } else {
              root.showMainInterface()
            }
          }

        }
        Text {
          width: parent.width - Style.space(40)
          text: root.service ? root.service.browseTitle : "Music"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
        }
      }

      Rectangle {
        width: parent.width
        height: Style.space(34)
        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 3.5)
        radius: Style.cornerRadius
        TextInput {
          id: musicSearch
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          verticalAlignment: TextInput.AlignVCenter
          color: root.bar ? root.bar.foreground : Color.foreground
          selectionColor: Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          clip: true
          text: root.service ? root.service.searchQuery : ""
          onAccepted: if (root.service) root.service.search(text)
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Search music"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.7)
            font: parent.font
            visible: !parent.text && !parent.activeFocus
          }
        }

      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        Rectangle {
          width: 120
          height: Style.space(32)
          color: Color.popups.background
          border.color: root.bar ? root.bar.foreground : Color.foreground
          border.width: Style.space(1)
          opacity: root.service && root.service.selectedHost && !root.service.libraryActionStatus ? 1 : 0.45
          Text {
            id: updateActionText
            anchors.centerIn: parent
            text: "UPDATE"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          TapHandler {
            enabled: root.service && root.service.selectedHost && !root.service.libraryActionStatus
            onTapped: root.service.updateLibrary()
          }
        }
        Rectangle {
          width: 120
          height: Style.space(32)
          color: Color.popups.background
          border.color: root.bar ? root.bar.foreground : Color.foreground
          border.width: Style.space(1)
          opacity: root.service && root.service.selectedHost && !root.service.libraryActionStatus ? 1 : 0.45
          Text {
            id: rescanActionText
            anchors.centerIn: parent
            text: "RESCAN"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          TapHandler {
            enabled: root.service && root.service.selectedHost && !root.service.libraryActionStatus
            onTapped: root.service.rescanLibrary()
          }
        }
        visible: root.isMusicLibraryView()
      }

      Text {
        width: parent.width
        text: root.service && root.service.libraryActionError
          ? root.service.libraryActionError
          : root.service && root.service.libraryActionStatus
            ? root.service.libraryActionStatus : ""
        color: root.service && root.service.libraryActionError ? "#e06c75" : Color.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        visible: text !== "" && root.isMusicLibraryView()
      }

      ListView {
        id: musicList
        width: parent.width
        height: Style.space(390)
        clip: true
        model: root.service ? root.service.browseItems : []
        delegate: Rectangle {
          required property var modelData
          readonly property bool isAlbumItem: String(modelData.uri || "").indexOf("albums://") === 0
            || String(modelData.type || "").toLowerCase() === "album"
          readonly property bool isRadioItem: modelData.service === "webradio"
            || ["radio", "station", "stream", "webradio", "mywebradio"].indexOf(
              String(modelData.type || "").toLowerCase()) >= 0
          readonly property bool isPlaylistItem: String(modelData.type || "").toLowerCase() === "playlist"
          readonly property string categoryGlyph: root.apiIconGlyph(modelData.icon, modelData.title)
          width: musicList.width
          height: Style.space(52)
          radius: Style.cornerRadius
          color: musicHover.hovered
            ? Style.hoverFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            : "transparent"
          HoverHandler { id: musicHover }
          Image {
            id: itemArt
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(44)
            height: Style.space(44)
            source: {
              var art = modelData.albumArt || ""
              if (!art || !root.service) return ""
              return /^https?:\/\//.test(art) ? art
                : "http://" + root.service.selectedHost + ":3000" + (art.charAt(0) === "/" ? art : "/" + art)
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready && !categoryGlyph
          }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(34)
            text: categoryGlyph
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
          }
          Text {
            anchors.left: parent.left
            anchors.leftMargin: itemArt.visible || categoryGlyph ? Style.space(50) : Style.space(10)
            anchors.right: actionButtons.left
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.artist ? modelData.artist + " - " + modelData.title : modelData.title
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
          Row {
            id: actionButtons
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(60)
            spacing: Style.space(4)
            TextButton {
              compact: true
              text: "+"
              visible: modelData.playable === true && !isRadioItem
              onClicked: if (root.service) root.service.action(modelData, "queue")
            }
            TextButton {
              compact: true
              text: ">"
              visible: modelData.playable === true
              onClicked: {
                if (root.service) root.service.play(modelData)
                root.showMainInterface()
              }
            }
            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius
              visible: isAlbumItem || isPlaylistItem
                || String(modelData.type || "").toLowerCase() === "folder"
              color: Color.popups.background
              border.color: Color.accent
              border.width: Style.space(1)
              Text {
                anchors.centerIn: parent
                text: "+"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }
              TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: if (root.service) root.service.action(modelData, "queue")
              }
            }
            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius
              visible: isAlbumItem || isPlaylistItem
                || String(modelData.type || "").toLowerCase() === "folder"
              color: Color.accent
              Text {
                anchors.centerIn: parent
                text: ">"
                color: root.selectedTrackForeground()
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }
              TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: {
                  if (!root.service) return
                  if (modelData.playable) {
                    root.service.play(modelData)
                    root.showMainInterface()
                  } else if (modelData.container) {
                    root.service.openBrowse(modelData.uri, modelData.title)
                  }
                }
              }
            }
          }
          TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
              if (!root.service) return
              if (modelData.playable) {
                root.service.play(modelData)
                root.showMainInterface()
              } else if (modelData.container) {
                root.service.openBrowse(modelData.uri, modelData.title)
              }
            }
          }
        }
      }

      Text {
        width: parent.width
        text: root.service && root.service.browseLoading ? "Loading music..."
          : root.service && root.service.browseError ? root.service.browseError
          : root.service && !root.service.selectedHost ? "No Volumio player discovered"
          : root.service && !root.service.browseItems.length ? "No music found" : ""
        color: root.service && root.service.browseError ? "#e06c75"
          : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        visible: text !== ""
      }

    }
    PanelKeyCatcher {
      id: musicKeys
      anchors.fill: parent
      onCloseRequested: root.escapeFromMenu()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(520))
    contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(560))
    focusTarget: mainKeys

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
            id: albumArtImage
            anchors.fill: parent
            source: root.albumArtUrl()
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
          }
          Text {
            anchors.centerIn: parent
            text: "♪"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.display
            visible: albumArtImage.status !== Image.Ready
          }
        }

        Column {
          anchors.left: cover.right
          anchors.leftMargin: Style.space(18)
          anchors.right: volumeCluster.left
          anchors.rightMargin: Style.space(10)
          anchors.top: parent.top
          anchors.topMargin: Style.space(44)
          spacing: Style.space(5)

          Text {
            width: parent.width
            text: root.service && root.service.title ? root.service.title : "Loading Volumio"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
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
          Text {
            width: parent.width
            text: {
              if (!root.service) return ""
              var details = []
              var addDetail = function(value) {
                if (!value) return
                var normalized = String(value).toLowerCase().replace(/\s+/g, "")
                for (var i = 0; i < details.length; i++) {
                  if (String(details[i]).toLowerCase().replace(/\s+/g, "") === normalized)
                    return
                }
                details.push(value)
              }
              addDetail(root.service.trackType)
              addDetail(root.service.bitrate)
              addDetail(root.service.sampleRate)
              addDetail(root.service.bitDepth)
              return details.join(" · ")
            }
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            visible: text !== ""
          }
        }

        Item {
          id: volumeCluster
          anchors.right: parent.right
          anchors.top: parent.top
          width: Style.space(52)
          height: Style.space(52)

          Canvas {
            id: volumeRing
            width: Style.space(52)
            height: Style.space(52)
            anchors.fill: parent
            onPaint: {
              var context = getContext("2d")
              var center = width / 2
              var radius = center - 6
              var value = root.service ? Math.max(0, Math.min(100, root.service.volume)) : 0
              context.reset()
              context.beginPath()
              context.arc(center, center, radius, 0, Math.PI * 2)
              context.strokeStyle = Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 2.5)
              context.lineWidth = 6
              context.stroke()
              context.beginPath()
              context.arc(center, center, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * value / 100)
              context.strokeStyle = Color.accent
              context.lineWidth = 6
              context.stroke()
            }
            Connections {
              target: root.service
              function onVolumeChanged() { volumeRing.requestPaint() }
            }
            Component.onCompleted: requestPaint()
          }
          MouseArea {
            anchors.centerIn: volumeRing
            width: volumeRing.width
            height: volumeRing.height
            onClicked: function(mouse) {
              var center = width / 2
              var dx = mouse.x - center
              var dy = mouse.y - center
              if (Math.sqrt(dx * dx + dy * dy) > center) return
              var angle = Math.atan2(dy, dx) + Math.PI / 2
              if (angle < 0) angle += Math.PI * 2
              root.flashButton("volume")
              if (root.service) root.service.setVolume(angle / (Math.PI * 2) * 100)
            }
          }
          Text {
            anchors.centerIn: volumeRing
            text: root.service ? Math.round(root.service.volume) : "-"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
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
          height: Style.space(6)
          color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 2.5)
          Rectangle {
            width: parent.width * (root.service && root.service.duration > 0 ? Math.min(1, root.service.seek / root.service.duration) : 0)
            height: parent.height
            color: Color.accent
          }
          MouseArea {
            z: 10
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

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(10)
        TextButton {
          text: "MUTE"
          selected: root.service && root.service.muted
          opacity: selected ? 1.0 : 0.45
          onClicked: { root.flashButton("mute"); if (root.service) root.service.toggleMute() }
        }
        TextButton {
          text: "SHUFFLE"
          selected: root.service && root.service.shuffle
          opacity: selected ? 1.0 : 0.45
          onClicked: { root.flashButton("shuffle"); if (root.service) root.service.toggleShuffle() }
        }
        TextButton {
          text: "FAV"
          opacity: root.service && root.service.currentUri ? 1.0 : 0.45
          onClicked: { root.flashButton("favorite"); if (root.service) root.service.favoriteCurrentTrack() }
        }
        TextButton {
          text: "MUSIC"
          onClicked: {
            root.close()
            root.musicOpen = true
            if (root.service) root.service.loadBrowseSources()
          }
        }
        TextButton {
          text: "PLS"
          onClicked: {
            root.close()
            Qt.callLater(function() {
              root.playlistOpen = true
              if (root.service) root.service.refreshQueue()
            })
          }
        }
      }

      Text {
        width: parent.width
        text: root.service ? root.service.favoriteStatus : ""
        visible: text !== ""
        horizontalAlignment: Text.AlignHCenter
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
    PanelKeyCatcher {
      id: mainKeys
      anchors.fill: parent
      onCloseRequested: root.closeAll()
    }
  }

  KeyboardPanel {
    id: playlistPopup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.playlistOpen
    contentWidth: playlistPopup.fittedContentWidth(Style.space(520))
    contentHeight: playlistPopup.fittedContentHeight(playlistContent.implicitHeight, Style.space(560))
    focusTarget: playlistKeys

    Rectangle {
      anchors.fill: parent
      color: Color.popups.background
      z: 0
    }

    Column {
      id: playlistContent
      width: parent.width
      z: 1
      spacing: Style.space(10)

      Text {
        text: "PLAYLIST"
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      ListView {
        id: playlistView
        width: parent.width
        height: Math.min(contentHeight, Style.space(430))
        implicitHeight: contentHeight
        clip: true
        model: root.service ? root.service.queue : []
        onCountChanged: Qt.callLater(root.positionCurrentTrack)
        delegate: Rectangle {
          required property var modelData
          required property int index
          readonly property bool isCurrent: modelData.uri === (root.service ? root.service.currentUri : "")
          readonly property bool isHovered: rowHover.hovered
          width: ListView.view.width
          height: Style.space(42)
          color: isHovered
            ? Style.hoverFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            : isCurrent ? Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            : "transparent"
          radius: Style.cornerRadius

          HoverHandler {
            id: rowHover
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(28)
            text: modelData.tracknumber > 0 ? modelData.tracknumber : index + 1
            color: isCurrent && !isHovered
              ? root.selectedTrackForeground()
              : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(45)
            text: Number(modelData.duration) > 0 ? root.timeText(modelData.duration) : ""
            color: isCurrent && !isHovered
              ? root.selectedTrackForeground()
              : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            visible: text !== ""
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(48)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(65)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            text: modelData.artist
              ? modelData.artist + " - " + (modelData.name || "Unknown track")
              : (modelData.name || "Unknown track")
            color: isCurrent && !isHovered
              ? root.selectedTrackForeground()
              : root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.bold: isCurrent
            elide: Text.ElideRight
          }

          Connections {
            target: root.service
            function onCurrentUriChanged() { Qt.callLater(root.positionCurrentTrack) }
            function onQueueChanged() { Qt.callLater(root.positionCurrentTrack) }
          }

          TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
              root.flashButton("play")
              if (root.service) root.service.playQueueItem(modelData.uri)
            }
          }

        }
      }

      Text {
        width: parent.width
        text: root.service && root.service.queue.length ? "" : "No tracks in queue"
        color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.35)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        visible: text !== ""
      }

      TextButton {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "BACK"
        onClicked: {
          root.playlistOpen = false
          root.open()
        }
      }

    }

    PanelKeyCatcher {
      id: playlistKeys
      anchors.fill: parent
      onCloseRequested: root.escapeFromMenu()
    }
  }

  component TextButton: Button {
    id: buttonRoot
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
