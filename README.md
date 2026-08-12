# Breathlet

![Breathlet](docs/breathlet-icon.png)

A tiny native macOS menu bar app that reminds you to rest after a focused work interval.

## Features

- Menu bar countdown with pause/resume.
- Take a break now, skip, or reset the timer right from the menu bar.
- Full-screen break mask across all displays, with optional fade-in.
- Animated break overlay with rotating wellness action symbols.
- Configurable eye-break schedule (interval and duration).
- Optional stand-up break on its own schedule.
- Optional gradual wake-up fade before a break ends.
- Optional break-end sound and mouse-inactivity pause.
- Launch at system startup; show or hide the countdown in the menu bar.
- Check for updates in the About pane, backed by a here.now-hosted update manifest.
- Localized UI (English / 简体中文) — follows the system language, or pick one in Preferences.
- Preferences with General settings and per-break Schedule/Appearance tabs.

## Download

Grab the latest DMG from the [Releases page](https://github.com/lzc8568/breathlet/releases), or from the [here.now download page](https://emerald-globe-xmny.here.now/).

## Build

Open `Breathlet.xcodeproj` in Xcode and run the `Breathlet` scheme.

Or use Make:

```sh
make build
make install
make dmg
```

`make install` builds the Release app, installs the current build to `/Applications/Breathlet.app`, and launches it.

## Release

Push a tag to build a DMG, publish a GitHub Release, and update the here.now download page:

```sh
git tag v1.3.2
git push origin v1.3.2
```

The workflow also regenerates `latest.json` on the here.now site, which the app's "Check for Updates" reads. Publishing requires the `HERENOW_API_KEY` secret; without it the step is skipped (the GitHub Release is still published).

Command line build also works once the active developer directory points to full Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -project Breathlet.xcodeproj -scheme Breathlet -configuration Debug build
```
