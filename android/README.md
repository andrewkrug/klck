# Klck — Android

A native Android port of [Klck](../README.md), the sample-accurate metronome
for iPhone, iPad, and macOS. Same product, same name, same audio premise —
written in Kotlin + Jetpack Compose, with a low-latency AudioTrack engine
that mirrors the Swift `AVAudioSourceNode` render-loop pattern.

This module lives alongside the Swift sources in a single repo so the
launch story (privacy policy, brand, license) stays unified.

## Status

**v0 / MVP** — boot, set tempo, set time signature, set per-beat accents,
start/stop. Subdivisions, swing, the chromatic tuner, setlists, and presets
ship in follow-ups. (See [the deferred-features list](#deferred).)

## Why native Android

The whole point of Klck is sample-accurate click timing. On Apple platforms
that's `AVAudioSourceNode` with a render callback; on Android it has to be
written natively against `AudioTrack` (or `Oboe` / `AAudio` for sub-10ms
latency). No cross-platform framework lets us share the audio core, so
Flutter or React Native would mean rewriting the engine *and* the UI — more
work for less reuse. Native Android + Kotlin/Compose ports cleanly:

| Layer       | Swift                                | Kotlin / Android                                   |
|-------------|--------------------------------------|----------------------------------------------------|
| Model       | `MetronomeModel`, `Preset`, etc.     | `model/*.kt` (mechanical port)                     |
| Audio       | `AVAudioSourceNode` render callback  | `MetronomeEngine` + AudioTrack streaming loop      |
| UI          | SwiftUI                              | Jetpack Compose (Material 3)                       |
| Persistence | `Codable` + JSON file in container   | (deferred — DataStore/proto + JSON)                |

## Build

Requirements: Android Studio Hedgehog+ (or just the bundled JDK 21 + the
Android SDK at `~/Library/Android/sdk`).

```sh
cd android
./gradlew :app:assembleDebug          # writes app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:installDebug           # install on a connected device or running emulator
```

First build downloads Gradle 8.7 + the Android Gradle Plugin + all the
Compose dependencies (~250 MB into `~/.gradle/`). Subsequent builds are
incremental and finish in a few seconds.

## Layout

```
android/
├── build.gradle.kts                  # root (alias-only)
├── settings.gradle.kts               # includes :app
├── gradle/libs.versions.toml         # version catalog
└── app/
    ├── build.gradle.kts              # AGP / Kotlin / Compose plugins + deps
    └── src/main/
        ├── AndroidManifest.xml
        ├── java/com/klck/metronome/
        │   ├── MainActivity.kt        # Compose entry
        │   ├── MetronomeViewModel.kt  # bridges engine ↔ StateFlow
        │   ├── audio/
        │   │   ├── ClickRenderer.kt   # one-shot click envelope synth
        │   │   └── MetronomeEngine.kt # AudioTrack render loop
        │   ├── model/                 # ported from Sources/Klck/Model/
        │   │   ├── BeatAccent.kt
        │   │   ├── ClickWaveform.kt
        │   │   ├── Preset.kt
        │   │   ├── Setlist.kt
        │   │   └── SubLayer.kt
        │   └── ui/
        │       ├── MetronomeScreen.kt # the one-screen MVP UI
        │       └── theme/Theme.kt     # DB-66-inspired dark palette
        └── res/                       # icons, themes, strings
```

## Architecture notes

- **Audio thread is just `Dispatchers.Default`** with a `while (isActive)`
  loop that fills a 1024-frame Float PCM buffer per iteration (~21 ms @
  48 kHz) and writes to `AudioTrack` in blocking mode — the write blocks
  paces the loop. State mutation from the UI thread is `@Volatile`;
  re-read at chunk boundaries so changes take effect within ~one buffer.
- **No JNI / NDK** in the MVP. AudioTrack with
  `PERFORMANCE_MODE_LOW_LATENCY` is good enough for a metronome. Switching
  to **Oboe** (C++ via prefab AAR) is a one-file follow-up if real-world
  device testing shows the latency is too high.
- **One-shot click voices** are pre-rendered (`ClickRenderer`) when each
  beat is scheduled, then mixed into the output stream — same model as the
  Swift engine, just simpler bookkeeping.

## <a name="deferred"></a>Deferred features (parity with iOS)

- Subdivision grid (8ths + triplets + 16ths) — engine groundwork already
  in `ClickWaveform`/`SubLayer`; UI + render-loop scheduling pending.
- Swing (off-beat 8th/16th delay)
- Quiet Count, Tempo Trainer, Practice Timer
- Setlists / Preset chaining
- Chromatic tuner (mic + autocorrelation)
- Reference tone generator
- Persistence (DataStore + JSON migration of Preset/Setlist)
- Adaptive launcher icon + Play Store assets

## License

MIT, same as the rest of the repo.
