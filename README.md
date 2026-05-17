# Klck

A sample-accurate metronome for macOS, built with SwiftUI and `AVAudioEngine`.
Designed for practice: per-beat accents, layered subdivisions, swing, a tempo
trainer, Quiet Count, and a practice timer.

An open-source, community-supported metronome.

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
- **Per-role sounds** — independent timbre (Sine, Wood, Beep, Click) for the
  accent, the normal beat, and each subdivision layer
- **Quiet Count** — play N bars, then auto-mute M bars so you hold time yourself
- **Tempo Trainer** — ramp BPM from a start to a target by +N every M measures
- **Practice Timer** — run for a set duration with a live countdown, then auto-stop
- **Beat flash** — the screen pulses in time, brighter on the downbeat (toggle)
- **Setlists** — chain presets into an ordered list; step with PREV/NEXT
  (`[` / `]`) or auto-advance each stop after a set number of bars

**Tuner & Tone**
- **Chromatic tuner** — microphone pitch detection with note name, frequency,
  and a ±50-cent meter (autocorrelation + parabolic interpolation)
- **Tone generator** — sustained reference pitch, semitone stepping, A=440
  preset, and volume; runs with or without the metronome

The audio engine computes all click timing in absolute sample frames inside the
`AVAudioSourceNode` render callback, so timing is immune to UI/timer jitter.

The tuner needs microphone access; macOS will prompt on first use.

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
7. Press **SAVE** to store the full configuration; **MEMORY** recalls or
   deletes presets.
8. In **Tuner & Tone**, press **LISTEN** to tune by mic, or enable **Tone**
   for a reference pitch.
9. In **MEMORY ▸ Setlists**, create a setlist, add presets from the Presets
   tab (**+SET**), optionally set per-stop auto-advance bars, then step with
   **PREV/NEXT** on the deck.

### Keyboard shortcuts

| Key     | Action            |
|---------|-------------------|
| `Space` | Start / Stop      |
| `T`     | Tap tempo         |
| `[`     | Setlist previous  |
| `]`     | Setlist next      |

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

Planned: an iOS companion app.

## License

Released under the [MIT License](LICENSE). Contributions welcome.
