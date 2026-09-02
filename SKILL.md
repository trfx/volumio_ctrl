# Volumio Control Plugin Skill

## Project

- Location: `/home/tune/.config/omarchy/plugins/volumio_ctrl`
- Omarchy Quickshell plugin for discovering and controlling Volumio players.
- Entry points:
  - `Service.qml`: discovery, state polling, queue loading, and Volumio commands.
  - `Panel.qml`: main control panel and playlist popup.
  - `BarWidget.qml`: bar integration.
  - `manifest.json`: plugin metadata.

## Local development

Use the plugin repository directly:

```sh
cd /home/tune/.config/omarchy/plugins/volumio_ctrl
git status --short --branch
omarchy plugin validate .
omarchy restart shell
```

Saving files under `~/.config/omarchy/plugins/` normally triggers a reload, but
`omarchy restart shell` is the reliable way to apply and verify changes.

## Volumio API behavior

- Discover players with `avahi-browse -rt _Volumio._tcp`.
- State endpoint: `/api/v1/getState`.
- Queue endpoint: `/api/v1/getQueue`.
- Command endpoint: `/api/v1/commands/?cmd=...`.
- This player reports playback position in `seek` milliseconds; divide by 1000
  for display.
- The state `position` field is not the playback position and should not be
  used for the progress bar.
- `seek&position=<seconds>` works for seeking; `seek&value=...` does not.
- Queue track selection uses `play&N=<queue-index>`; `play&value=...` does not
  select tracks reliably.
- The state may return `seek: null`; retain the last valid position rather than
  resetting the progress bar.
- Optional audio fields include `trackType`, `bitrate`, `samplerate`, and
  `bitdepth`; omit fields that are absent.
- Queue rows are matched to the current track by URI.

## UI conventions

- Use `KeyboardPanel` for popup windows.
- Use `Style.hoverFillFor(...)` for hover illumination.
- Use `Style.selectedFillFor(...)` for active/selected illumination.
- The playlist popup auto-scrolls to the current URI and has clickable rows.
- The volume ring is circular, clickable, 52px, with a 6px stroke.
- The progress bar is 6px thick and click-to-seek.
- Track titles wrap to a maximum of two lines.
- Keep metadata to the right of the cover and constrain it before the volume
  ring to prevent overlap.

## Branch state

- `main` contains the previously merged click-to-seek and volume-ring work.
- Ongoing UI work is on branch `info-repositioning`.
- Do not commit or push unless explicitly requested.
