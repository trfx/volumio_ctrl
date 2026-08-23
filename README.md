# Volumio Control

A minimal Omarchy Quattro plugin for Volumio players on the local LAN.

It discovers `_Volumio._tcp` services with `avahi-browse`, reads playback state from the Volumio HTTP API, and provides track metadata, progress, play/pause, and volume controls.

## Requirements

- Omarchy Quattro with the plugin directory enabled
- `avahi-browse` and `curl`

## Install

```sh
omarchy plugin validate ~/.config/omarchy/plugins/volumio_ctrl
omarchy plugin enable volumio_ctrl
```

Add `volumio_ctrl` to the bar layout. Discovery runs when the service initializes. Multiple players can be selected from the panel.

## TODO
- Volumio icon
- interactive progress bar
- interactive volume ring
- better positioning of track title and artist
