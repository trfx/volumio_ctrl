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
  property string stateService: ""
  property double duration: 0
  property double seek: 0
  property int volume: 0
  property bool muted: false
  property bool isPlaying: false
  property bool shuffle: false
  property string error: ""
  property var queue: []
  property var browseSources: []
  property var browseItems: []
  property var browseHistory: []
  property string browseUri: ""
  property string browseTitle: "Music"
  property bool browseLibraryView: false
  property string browseError: ""
  property string searchQuery: ""
  property bool browseLoading: false
  property string libraryActionStatus: ""
  property string libraryActionError: ""
  property string favoriteStatus: ""
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
    if (devices.length) loadBrowseSources()
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

  function browse(uri) {
    if (!selectedHost || browseRequest.running) return
    browseUri = uri || ""
    browseLoading = true
    browseError = ""
    browseRequest.command = ["curl", "-fsS", "--max-time", "5",
      "http://" + selectedHost + ":3000/api/v1/browse" + (uri ? "?uri=" + encodeURIComponent(uri) : "")]
    browseRequest.running = true
  }

  function openBrowse(uri, title) {
    browseHistory = browseHistory.concat([{
      uri: browseUri,
      title: browseTitle,
      libraryView: browseLibraryView
    }])
    browseTitle = title || "Music"
    browseLibraryView = browseLibraryView || String(title || "").toLowerCase() === "music library"
    browse(uri || "")
  }

  function goBackBrowse() {
    if (!browseHistory.length) {
      browseTitle = "Music"
      browseLibraryView = false
      browseUri = ""
      browse("")
      return
    }
    var history = browseHistory.slice()
    var previous = history.pop()
    browseHistory = history
    browseTitle = previous.title || "Music"
    browseLibraryView = previous.libraryView === true
    browse(previous.uri || "")
  }

  function search(query) {
    var value = String(query || "").trim()
    if (!selectedHost || !value || searchRequest.running) return
    searchQuery = value
    browseLoading = true
    browseError = ""
    searchRequest.command = ["curl", "-fsS", "--max-time", "5",
      "http://" + selectedHost + ":3000/api/v1/search?query=" + encodeURIComponent(value)
      + (browseUri ? "&uri=" + encodeURIComponent(browseUri) : "")]
    searchRequest.running = true
  }

  function normalizedItem(item) {
    var value = item || {}
    var itemType = String(value.type || value.itemType || value.trackType || "").toLowerCase()
    var itemUri = String(value.uri || "")
    var playableTypes = ["song", "track", "radio", "station", "stream", "webradio", "mywebradio"]
    var isWebRadio = ["radio", "station", "stream", "webradio", "mywebradio"].indexOf(itemType) >= 0
      || String(value.service || value.plugin || "").toLowerCase() === "webradio"
      || !!itemUri && /^https?:\/\//.test(itemUri)
    var playable = value.playable === true || value.playable === "true"
      || !!value.uri && (playableTypes.indexOf(itemType) >= 0 || !!value.trackType)
    var isAlbum = itemType === "album"
      || (itemType === "folder" && itemUri.indexOf("albums://") === 0)
    var container = value.container === true || value.container === "true"
      || ["folder", "album", "artist", "playlist", "genre", "category", "source",
        "radio-category", "mywebradio-category", "radio-favourites", "radio-folder",
        "remdisk"].indexOf(itemType) >= 0
      || !!value.uri && !playable
    return {
      title: String(value.title || value.name || "Untitled"),
      artist: String(value.artist || ""),
      album: String(value.album || ""),
      type: itemType,
      uri: itemUri,
      albumArt: String(value.albumart || value.albumArt || ""),
      icon: String(value.icon || ""),
      duration: Number(value.duration || 0),
      service: String(value.service || value.plugin || ""),
      playable: playable,
      isWebRadio: isWebRadio,
      isAlbum: isAlbum,
      container: container,
      actions: Array.isArray(value.actions) ? value.actions : [],
      raw: value
    }
  }

  function responseItems(response) {
    if (Array.isArray(response)) return response
    if (response && Array.isArray(response.items)) return response.items
    var lists = response && response.navigation && Array.isArray(response.navigation.lists)
      ? response.navigation.lists : []
    var items = []
    var hasItems = false
    for (var i = 0; i < lists.length; i++) {
      if (Array.isArray(lists[i])) {
        hasItems = true
        items = items.concat(lists[i])
      } else if (Array.isArray(lists[i].items)) {
        hasItems = true
        items = items.concat(lists[i].items)
      }
    }
    return hasItems ? items : lists
  }

  function action(item, operation) {
    if (!selectedHost || !item || !item.uri || actionRequest.running) return
    var endpoint = operation === "play" ? "replaceAndPlay"
      : operation === "addPlay" ? "addPlay" : "addToQueue"
    var payload = item.raw || item
    if (operation === "play" && item.isWebRadio === true) {
      var radioPayload = item.raw
        ? JSON.parse(JSON.stringify(item.raw))
        : {}
      radioPayload.service = radioPayload.service || radioPayload.plugin || "webradio"
      radioPayload.type = radioPayload.type || radioPayload.itemType || "webradio"
      radioPayload.title = radioPayload.title || radioPayload.name || item.title
      radioPayload.uri = item.uri
      radioPayload.albumart = radioPayload.albumart || radioPayload.albumArt || item.albumArt || ""
      payload = { list: [radioPayload], index: 0 }
    } else if (operation === "play" && item.playable === true) {
      var siblings = []
      for (var i = 0; i < browseItems.length; i++) {
        var sibling = browseItems[i]
        if (sibling.playable === true && sibling.isWebRadio !== true)
          siblings.push(sibling)
      }
      if (siblings.length > 1) {
        var selectedIndex = 0
        for (var j = 0; j < siblings.length; j++) {
          if (siblings[j].uri === item.uri) {
            selectedIndex = j
            break
          }
        }
        var ordered = siblings.slice(selectedIndex).concat(siblings.slice(0, selectedIndex))
        var trackList = []
        for (var k = 0; k < ordered.length; k++) {
          var track = ordered[k]
          var trackPayload = track.raw
            ? JSON.parse(JSON.stringify(track.raw))
            : {}
          trackPayload.title = trackPayload.title || trackPayload.name || track.title
          trackPayload.uri = track.uri
          trackPayload.albumart = trackPayload.albumart || trackPayload.albumArt || track.albumArt || ""
          trackList.push(trackPayload)
        }
        payload = { list: trackList, index: 0 }
      }
    }
    actionRequest.command = ["curl", "-fsS", "--max-time", "5", "-X", "POST",
      "-H", "Content-Type: application/json", "-d", JSON.stringify(payload),
      "http://" + selectedHost + ":3000/api/v1/" + endpoint]
    actionRequest.running = true
  }

  function play(item) {
    if (!item || !item.uri) return
    action(item, "play")
  }

  function loadBrowseSources() {
    browseHistory = []
    browseUri = ""
    browseTitle = "Music"
    browseLibraryView = false
    browse("")
  }

  function updateLibrary() {
    var path = browseUri.indexOf("music-library/") === 0 ? browseUri : ""
    runLibraryAction("updateDb", path)
  }

  function rescanLibrary() {
    runLibraryAction("rescanDb", "")
  }

  function runLibraryAction(action, path) {
    if (!selectedHost || libraryActionRequest.running) return
    libraryActionStatus = action === "rescanDb" ? "Rescanning music library..."
      : "Updating music library..."
    libraryActionError = ""
    var helperPath = Qt.resolvedUrl("volumio_library_action.py").toString().replace(/^file:\/\//, "")
    var args = ["/usr/bin/env", "python3", helperPath,
      selectedHost, action]
    if (action === "updateDb" && path) args.push(path)
    libraryActionRequest.command = args
    libraryActionRequest.running = true
  }

  function favoriteCurrentTrack() {
    if (!selectedHost || favoriteRequest.running) return
    if (!currentUri) {
      favoriteStatus = "Cannot favorite: no track URI"
      return
    }
    var radioType = trackType.toLowerCase()
    var serviceName = radioType === "webradio" || stateService.toLowerCase() === "webradio"
      ? "webradio" : (stateService || "mpd")
    var payload = {
      service: serviceName,
      uri: currentUri,
      title: title
    }
    favoriteStatus = "Saving favorite..."
    var helperPath = Qt.resolvedUrl("volumio_library_action.py").toString().replace(/^file:\/\//, "")
    favoriteRequest.command = ["/usr/bin/env", "python3", helperPath,
      selectedHost, "addToFavourites", JSON.stringify(payload)]
    favoriteRequest.running = true
  }

  function command(name) {
    if (!selectedHost || commandRequest.running) return
    commandRequest.command = ["curl", "-fsS", "--max-time", "3", "http://" + selectedHost + ":3000/api/v1/commands/?cmd=" + name]
    commandRequest.running = true
  }

  function playPause() { command(isPlaying ? "pause" : "play") }
  function previous() { command("prev") }
  function next() { command("next") }
  function playQueueItem(uri) {
    if (!queue || !uri) return
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].uri === uri) {
        command("play&N=" + i)
        return
      }
    }
  }
  function seekTo(seconds) {
    if (duration <= 0) return
    var target = Math.max(0, Math.min(duration, Number(seconds) || 0))
    command("seek&position=" + Math.round(target))
  }
  function toggleShuffle() { command("random&value=" + (!shuffle)) }
  function toggleMute() { command("volume&volume=toggle") }
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
      stateService = String(state.service || "")
      trackType = String(state.trackType || "").toUpperCase()
      if (!trackType && currentUri) {
        var extension = currentUri.match(/\.([a-z0-9]{2,5})(?:$|[?#])/i)
        if (extension) trackType = extension[1].toUpperCase()
      }
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
      muted = state.mute === true || state.mute === "true" || state.mute === 1 || state.mute === "1"
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
    id: browseRequest
    stdout: StdioCollector { id: browseOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.browseLoading = false
      if (exitCode !== 0) {
        root.browseError = "Music sources are unavailable"
        return
      }
      try {
        var response = JSON.parse(String(browseOutput.text || ""))
        var items = root.responseItems(response)
        root.browseUri = String(response.uri || root.browseUri || "")
        root.browseTitle = String(response.title || root.browseTitle || "Music")
        var normalized = items.map(root.normalizedItem)
        console.log("Volumio browse", root.selectedHost, "items:", normalized.length)
        if (!root.browseUri && !root.browseHistory.length) root.browseSources = normalized
        root.browseItems = normalized
        root.browseError = ""
      } catch (e) {
        root.browseError = "Invalid music response from " + root.selectedName
      }
    }
  }

  Process {
    id: searchRequest
    stdout: StdioCollector { id: searchOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.browseLoading = false
      if (exitCode !== 0) {
        root.browseError = "Music search failed"
        return
      }
      try {
        var response = JSON.parse(String(searchOutput.text || ""))
        var items = root.responseItems(response)
        root.browseItems = items.map(root.normalizedItem)
        console.log("Volumio search", root.selectedHost, "items:", root.browseItems.length)
        root.browseTitle = "Search: " + root.searchQuery
        root.browseError = ""
      } catch (e) {
        root.browseError = "Invalid search response from " + root.selectedName
      }
    }
  }

  Process {
    id: actionRequest
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.browseError = "Music action failed"
        return
      }
      root.refreshQueue()
      refresh()
    }
  }

  Process {
    id: libraryActionRequest
    stdout: StdioCollector { id: libraryActionOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.libraryActionStatus = ""
        root.libraryActionError = "Library action failed"
        return
      }
      root.libraryActionError = ""
      root.libraryActionStatus = "Library action started"
      root.browse("")
      libraryActionRefresh.restart()
    }
  }

  Process {
    id: favoriteRequest
    stdout: StdioCollector { id: favoriteOutput; waitForEnd: true }
    onExited: function(exitCode) {
      favoriteStatus = exitCode === 0
        ? "Favorite saved"
        : "Could not save favorite"
    }
  }

  Timer {
    id: libraryActionRefresh
    interval: 1500
    repeat: false
    onTriggered: {
      root.libraryActionStatus = ""
      root.loadBrowseSources()
    }
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

  Component.onCompleted: { root.discover(); root.loadBrowseSources() }
  onSelectedIndexChanged: {
    root.title = ""
    root.browseHistory = []
    root.browseUri = ""
    root.browseTitle = "Music"
    root.browseLibraryView = false
    root.refresh()
    root.loadBrowseSources()
  }
}
