# Breathlet

A tiny native macOS menu bar app that reminds you to rest after a focused work interval.

## Features

- Menu bar countdown.
- Manual "Take Break Now" and timer reset actions.
- Full-screen break mask across all displays.
- Configurable eye break interval and duration.
- Animated break overlay with rotating wellness action symbols.
- Optional gradual wake-up fade before a break ends.
- General preferences matching the reference screenshots.
- Break preferences with Schedule and Appearance tabs.
- Optional fade-in mask, break-end sound, and mouse-inactivity pause.

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

Push a tag to build a DMG and publish a GitHub Release:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Command line build also works once the active developer directory points to full Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -project Breathlet.xcodeproj -scheme Breathlet -configuration Debug build
```
