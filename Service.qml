import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var devices: []
  property int selectedIndex: 0
  property string title: ""
  property string artist: ""
  property string album: ""
  property string currentUri: ""
  property string trackType: ""
  property string bitrate: ""
  property string sampleRate: ""
  property string bitDepth: ""
  property string albumArt: ""
  property string status: ""
  property double duration: 0
  property double seek: 0
  property int volume: 0
  property bool isPlaying: false
  property bool shuffle: false
  property string error: ""
  property var queue: []
  readonly property int volumeStep: 2

  readonly property var selectedDevice: devices.length > selectedIndex ? devices[selectedIndex] : null
  readonly property string selectedName: selectedDevice ? selectedDevice.name : ""
  readonly property string selectedHost: selectedDevice ? selectedDevice.host : ""

  function discover() {
    discovery.running = true
  }

  function parseDiscovery(raw) {
    var found = []
    var host = ""
    var name = "Volumio"
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var address = line.match(/address = \[([^\]]+)\]/)
      var serviceName = line.match(/IPv4 ([^ ]+)/)
      if (serviceName) name = serviceName[1]
      if (address) {
        host = address[1]
        if (found.every(function(device) { return device.host !== host }))
          found.push({ name: name, host: host })
        host = ""
      }
    }
    devices = found
    if (selectedIndex >= devices.length) selectedIndex = 0
    error = devices.length ? "" : "No Volumio devices found"
    refresh()
  }

  function refresh() {
    if (!selectedHost || stateRequest.running) return
    stateRequest.command = ["curl", "-fsS", "--max-time", "3", "http://" + selectedHost + ":3000/api/v1/getState"]
    stateRequest.running = true
  }
  function refreshQueue() {
    if (!selectedHost || queueRequest.running) return
    queueRequest.command = ["curl", "-fsS", "--max-time", "3", "http://" + selectedHost + ":3000/api/v1/getQueue"]
    queueRequest.running = true
  }

  function command(name) {
    if (!selectedHost || commandRequest.running) return
    commandRequest.command = ["curl", "-fsS", "--max-time", "3", "http://" + selectedHost + ":3000/api/v1/commands/?cmd=" + name]
    commandRequest.running = true
  }

  function playPause() { command(isPlaying ? "pause" : "play") }
  function previous() { command("prev") }
  function next() { command("next") }
  function seekTo(seconds) {
    if (duration <= 0) return
    var target = Math.max(0, Math.min(duration, Number(seconds) || 0))
    command("seek&position=" + Math.round(target))
  }
  function toggleShuffle() { command("random&value=" + (!shuffle)) }
  function setVolume(value) {
    var next = Math.max(0, Math.min(100, Math.round(Number(value) || 0)))
    command("volume&volume=" + next)
  }
  function volumeUp() { setVolume(volume + volumeStep) }
  function volumeDown() { setVolume(volume - volumeStep) }

  function applyState(raw) {
    try {
      var state = JSON.parse(String(raw || ""))
      title = String(state.title || "")
      artist = String(state.artist || "")
      album = String(state.album || "")
      currentUri = String(state.uri || "")
      trackType = String(state.trackType || "").toUpperCase()
      bitrate = String(state.bitrate || "")
      sampleRate = String(state.samplerate || "")
      bitDepth = String(state.bitdepth || "")
      albumArt = String(state.albumart || "")
      status = String(state.status || "")
      duration = Number(state.duration || 0)
      var reportedSeek = Number(state.seek) / 1000
      if (isFinite(reportedSeek) && reportedSeek >= 0 && reportedSeek <= duration)
        seek = reportedSeek
      volume = Number(state.volume || 0)
      isPlaying = status === "play"
      shuffle = !!(state.random || state.shuffle)
      error = ""
    } catch (e) {
      error = "Invalid response from " + selectedName
    }
  }

  Process {
    id: discovery
    command: ["avahi-browse", "-rt", "_Volumio._tcp"]
    stdout: StdioCollector { id: discoveryOutput; waitForEnd: true }
    onExited: root.parseDiscovery(discoveryOutput.text)
  }

  Process {
    id: stateRequest
    stdout: StdioCollector { id: stateOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.applyState(stateOutput.text)
      else root.error = "Volumio is unavailable"
    }
  }

  Process {
    id: queueRequest
    stdout: StdioCollector { id: queueOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.error = "Volumio playlist unavailable"
        return
      }
      try {
        var response = JSON.parse(String(queueOutput.text || ""))
        root.queue = Array.isArray(response.queue) ? response.queue : []
      } catch (e) {
        root.error = "Invalid playlist response from " + root.selectedName
      }
    }
  }

  Process {
    id: commandRequest
    stdout: StdioCollector { id: commandOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.error = "Volumio command failed"
      else root.refresh()
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.discover()
  onSelectedIndexChanged: { root.title = ""; root.refresh() }
}
