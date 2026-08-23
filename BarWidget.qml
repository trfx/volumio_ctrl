import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "volumio_ctrl"

  readonly property var volumio: bar && bar.shell ? bar.shell.serviceFor("volumio_ctrl") : null
  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false
  property var panelItem: null

  function open() { if (panelItem) panelItem.open() }
  function close() { if (panelItem) panelItem.close() }
  function togglePanel() {
    if (!panelItem) return
    if (panelItem.opened) panelItem.close()
    else panelItem.open()
  }
  function closeForPopoutSwitch() { if (panelItem) panelItem.closeForPopoutSwitch() }

  function injectPanel() {
    var panel = panelLoader.item
    if (!panel) return
    panelItem = panel
    panel.anchorItem = button
    panel.hostWidget = root
    panel.service = root.volumio
    panel.bar = root.bar
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onVolumioChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "VOL"
    tooltipText: root.volumio && root.volumio.selectedName
      ? "Volumio: " + root.volumio.selectedName
      : "Volumio"
    onPressed: root.togglePanel()
  }
}
