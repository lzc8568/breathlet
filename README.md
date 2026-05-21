# Breathlet

A tiny native macOS menu bar app that reminds you to rest after a focused work interval.

## Features

- Menu bar countdown.
- Manual "Take Break Now" and timer reset actions.
- Full-screen break mask across all displays.
- Configurable eye break interval and duration.
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

Command line build also works once the active developer directory points to full Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -project Breathlet.xcodeproj -scheme Breathlet -configuration Debug build
```

The current machine is using Command Line Tools only, so `xcodebuild` cannot run here until Xcode is selected.
