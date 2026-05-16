# Klck

A sample-accurate metronome for macOS, built with SwiftUI and `AVAudioEngine`.
Designed for practice: per-beat accents, layered subdivisions, swing, a tempo
trainer, Quiet Count, and a practice timer.

Inspired by the feature set of the Dr. Betotte / Beat Box iOS metronome.

## Features

**Core**
- Tempo 30–300 BPM with slider, ± steppers, and tap tempo (press `T`)
- Up to 16 beats per measure
- Per-beat accent grid — tap a beat to cycle **Accent → Normal → Muted**
- Four independent subdivision layers (8ths, triplets, 16ths, quarters) with
  per-layer volume and mute
- Master volume
- Named preset library, saved to disk and recallable from the sidebar

**Feel & Practice**
- **Swing** — 0–60%, delays off-beat 8th/16th subdivisions toward a triplet feel
- **Click sounds** — Sine, Wood, Beep, or Click (filtered noise)
- **Quiet Count** — play N bars, then auto-mute M bars so you hold time yourself
- **Tempo Trainer** — ramp BPM from a start to a target by +N every M measures
- **Practice Timer** — run for a set duration with a live countdown, then auto-stop

The audio engine computes all click timing in absolute sample frames inside the
`AVAudioSourceNode` render callback, so timing is immune to UI/timer jitter.

## Requirements

- macOS 13 or later
- A Swift 6+ toolchain — either **Xcode** or the **Command Line Tools**
  (`xcode-select --install`). Full Xcode is **not** required.

Check your toolchain:

```sh
make version      # or: swift --version
```

## Build & run

```sh
make            # build + assemble Klck.app  (default target)
make run        # build, then launch the app
make run-console  # launch with log output in the terminal
```

`make` produces `Klck.app` in the project root. Launch it with `open Klck.app`
or double-click it in Finder.

Other targets:

```sh
make help       # list all targets
make debug      # debug build
make check      # type-check only (no bundle)
make release    # clean, then build a fresh bundle
make clean      # remove .build/ and Klck.app
```

Under the hood, `make app` runs `./build_app.sh`, which does
`swift build -c release`, copies the binary and `Resources/Info.plist` into a
`.app` layout, and ad-hoc code-signs it so macOS will run it locally.

## Usage

1. `make run` to launch.
2. Set tempo with the slider, the ± buttons, or tap **Tap** (or press `T`) in
   rhythm.
3. Press **Start** (or the space bar) to begin; press again to stop.
4. Click numbered beats in the grid to set accents (loud), normal, or muted.
5. Toggle subdivision layers and set their volumes in **Subdivision layers**.
6. Open **Feel & Practice** for swing, click sound, Quiet Count, the Tempo
   Trainer, and the Practice Timer.
7. Use **Save Preset** (toolbar) to store the full configuration; recall or
   delete presets from the sidebar.

### Keyboard shortcuts

| Key     | Action       |
|---------|--------------|
| `Space` | Start / Stop |
| `T`     | Tap tempo    |

### Where presets are stored

```
~/Library/Application Support/Klck/presets.json
```

## Project layout

```
Package.swift              SwiftPM manifest (macOS 13+ executable)
Makefile                   build/run/clean targets
build_app.sh               swift build + .app bundle assembly
Resources/Info.plist       bundle metadata
Sources/Klck/
  KlckApp.swift            @main App entry
  Audio/AudioEngine.swift  sample-accurate render engine
  Model/                   MetronomeModel, SubLayer, Preset
  Views/                   SwiftUI interface
```

## Roadmap

Planned: per-role distinct sounds (accent vs. subdivision), setlists / preset
chaining, and an iOS companion app.

## License

Personal project — no license specified.
