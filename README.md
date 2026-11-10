# PuzzleBattery

A native SwiftUI battery utility for macOS 14 and later, inspired by the compact dashboard in [coconutBattery](https://www.coconut-flavour.com/coconutbattery/). Uses its own branding, icon, and implementation. No dependencies, accounts, or network requests.

## Run

Build a double-clickable app using Apple's Command Line Tools or Xcode with Swift 6 or later:

```sh
./scripts/build-app.sh
open build/PuzzleBattery.app
```

You can drag the built app into Applications. The script builds for the current Mac's architecture and applies a local ad-hoc signature. Public distribution requires Developer ID signing and notarization.

For development, open `Package.swift` in Xcode, or run:

```sh
swift run PuzzleBattery
./scripts/test.sh
```

The test script locates the Swift Testing macro plugin explicitly when using Command Line Tools, working around a missing plugin search path in preview toolchains.

## Features

- **This Mac:** live battery charge, health, actual mAh capacity, cycles, temperature, power, time estimate, and Low Power Mode.
- **History:** automatic daily readings while the app is running, manual snapshots, health chart, saved reading list, and CSV export.
- **Insights:** health summary, battery condition, voltage, current, adapter rating, and a copyable report.
- **Menu bar:** charge, health, power status, refresh, and quick access to the window.
- Mac and battery information sheets; configurable refresh interval and menu bar visibility.
- Native light/dark appearance, keyboard shortcuts, and accessibility labels.

Shortcuts: ⌘R refresh, ⌘S save, ⇧⌘C copy a report, ⌘, settings.

## Data and hardware support

Battery information is read with IOKit and the macOS Power Sources API. The parser handles both normalized Apple Silicon capacities and raw Intel mAh capacities, including unsigned representations of negative discharge current. Health is full charge capacity divided by design capacity; it can differ from the rounded figure in System Settings.

The app reads the Mac's internal battery. iPhone/iPad diagnostics, charge limiting, and private SMC controls are not implemented. Desktops show a no-battery state. Missing hardware fields show “Unavailable” or “Not reported”; modern battery manufacture-date encodings are not guessed. Time estimates come from macOS and may be unavailable while it calculates them. Adapter rating is the adapter's reported maximum, not its instantaneous power consumption.

Readings are stored atomically at `~/Library/Application Support/PuzzleBattery/history.json`, grouped by the local Mac's hardware UUID. Serial numbers are shown only in the battery information sheet and are excluded from history and copied reports. There is no background daemon: sampling and daily saving occur while PuzzleBattery runs. A damaged history file is preserved rather than silently overwritten.

## Source

- `Sources/BatteryCore`: battery normalization, derived metrics, and history serialization.
- `Sources/PuzzleBattery`: IOKit access, persistence, SwiftUI dashboard, settings, and menu bar.
- `Tests/BatteryCoreTests`: Apple Silicon/Intel fixtures, missing values, manufacture dates, and JSON/CSV round trips.
- `scripts/build-app.sh`: app bundle and icon generation.
