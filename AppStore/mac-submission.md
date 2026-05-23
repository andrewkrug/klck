# Mac App Store submission — Klck 1.0

Every field App Store Connect asks for when creating / submitting the macOS
version. Copy-paste straight in. If you've already enabled Universal Purchase
on the iOS app, most of the App Information section is shared with iOS — only
the version-specific fields (description, what's new, screenshots) are new.

---

## Platform setup

| Field        | Value                  |
|--------------|------------------------|
| Platform     | macOS                  |
| Bundle ID    | `com.klck.metronome`   |
| SKU          | `klck-mac-100`         |
| User Access  | Full Access            |

> **Tip:** Before submitting macOS, open the iOS app in App Store Connect →
> **App Information** → and click **"Make available on Mac"** to enable
> Universal Purchase. That way both platforms live under one App Store
> listing and one $1.99 purchase covers both. If you skip this and create a
> separate Mac record, the bundle ID conflict will block you.

---

## App Information

| Field                | Value                                  |
|----------------------|----------------------------------------|
| Name                 | `Klck`                                 |
| Subtitle (30 char)   | `Sample-accurate practice tool`        |
| Primary Language     | English (U.S.)                         |
| Primary Category     | Music                                  |
| Secondary Category   | Education                              |
| Content Rights       | Does not use third-party content       |
| Age Rating           | 4+ (answer **None** to every prompt)   |

---

## Pricing and Availability

| Field               | Value                                    |
|---------------------|------------------------------------------|
| Price               | **USD 1.99** (Tier 2)                    |
| Availability        | All territories                          |
| Pre-Order           | Off                                      |
| Educational Discount| Off                                      |
| Distribution        | Mac App Store                            |

---

## App Privacy

| Field                | Value                                                |
|----------------------|------------------------------------------------------|
| Privacy Policy URL   | `https://www.andrewkrug.com/klck/privacy/`           |
| Data Collection      | **Data Not Collected**                               |

Tracking domains: none. No third-party SDKs. Microphone audio (tuner) is
processed on-device only and never transmitted. The `PrivacyInfo.xcprivacy`
file in the bundle already declares all of this — App Privacy answers must
match.

---

## Version 1.0 (macOS)

### Description (4000 char limit — same as iOS works, included verbatim)

```
A precision metronome built for serious practice. Each click is scheduled in absolute sample frames inside the audio engine's render callback, so timing stays rock-solid — immune to UI jitter or app-switch lag.

CORE
• Tempo 30–300 BPM with slider, ± steppers, and tap tempo
• Up to 16 beats per measure with per-beat accents (Accent → Normal → Muted)
• Four independent subdivision layers — 8ths, triplets, 16ths, quarters — each with its own volume, mute, and timbre
• Per-role sounds: pick a distinct waveform (Sine, Wood, Beep, Click) for the accent, the normal beat, and every subdivision layer
• Master volume

PRACTICE TOOLS
• Swing 0–60%, delays the off-beat 8th/16th toward a triplet feel
• Quiet Count — play N bars then auto-mute M bars so you have to hold time yourself
• Tempo Trainer — ramp BPM from a start to a target by +N every M measures
• Practice Timer — run for a set duration with a live countdown, then auto-stop
• Beat flash — the screen pulses on the beat, brighter on the downbeat (toggleable)

SETLISTS
• Chain presets into an ordered list and step PREV/NEXT through them
• Optional per-stop auto-advance after a set number of bars
• Save and recall named presets that capture the full configuration

TUNER + TONE
• Chromatic tuner with note name, frequency, and a ±50-cent meter (autocorrelation + parabolic interpolation, on-device)
• Reference tone generator with semitone stepping, A=440 preset, and independent volume — runs with or without the metronome

PRIVACY
Klck does not collect, transmit, or share anything. No accounts, no analytics, no crash reporting, no advertising SDKs, no network requests. Microphone audio (used only for tuning) is analyzed on-device and discarded immediately.

OPEN SOURCE
Klck is community-supported software released under the MIT license. Full source is on GitHub.
```

### Promotional Text (170 char, editable any time without resubmission)

```
Open-source, sample-accurate metronome with per-beat accents, layered subdivisions, swing, tempo trainer, practice timer, chromatic tuner, and reference tone.
```

### Keywords (100 char, comma-separated, no spaces, do **not** include "Klck")

```
metronome,tuner,tempo,bpm,swing,drum,practice,subdivision,setlist,pitch,trainer,click,beat
```

### URLs

| Field             | Value                                            |
|-------------------|--------------------------------------------------|
| Support URL       | `https://github.com/andrewkrug/klck/issues`      |
| Marketing URL     | `https://www.andrewkrug.com/klck/`               |

### Copyright

```
© 2026 Andrew Krug
```

### Version Release

- Manually release this version (recommended for the first ship — you can
  hit publish the moment Apple approves rather than auto-releasing in the
  middle of the night).

### What's New in This Version

```
Initial macOS release. Universal Purchase: if you already own Klck on
iPhone or iPad, this is included.
```

(Or just `Initial macOS release.` if Universal Purchase isn't enabled.)

---

## Build

| Field             | Value                                                                    |
|-------------------|--------------------------------------------------------------------------|
| Build to attach   | `Klck 1.0 (1)` — uploaded from `build/pkg/Klck.pkg` via Transporter      |
| Signing           | `3rd Party Mac Developer Installer: Andrew Krug (S5N6TKYXS6)`            |
| Bundle ID         | `com.klck.metronome`                                                     |
| App Sandbox       | Enabled                                                                  |
| Hardened Runtime  | Enabled                                                                  |
| Entitlements      | `com.apple.security.app-sandbox`, `com.apple.security.device.audio-input`|

### Export Compliance

Already declared in code via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO`
(see `project.yml` and the value baked into `Klck.pkg`'s embedded
`Info.plist`). No re-answer needed on every upload.

If App Store Connect prompts anyway:

| Field                                          | Answer |
|------------------------------------------------|--------|
| Does your app use encryption?                  | **No** |

---

## Screenshots

Required minimum: **1** at one of the accepted Mac sizes (1280×800,
1440×900, 2560×1600, 2880×1800). Optional additions: up to 10.

| File                                          | Pixel size  | Slot                   |
|-----------------------------------------------|-------------|------------------------|
| `AppStore/screenshots/mac-1.png`              | 2880 × 1800 | Mac App (Default)      |

The image is the Klck window centered on a dark gradient, composed locally —
ready to upload as-is.

---

## App Review Information

| Field                | Value                                                      |
|----------------------|------------------------------------------------------------|
| Contact First Name   | Andrew                                                     |
| Contact Last Name    | Krug                                                       |
| Phone Number         | _(your number)_                                            |
| Email                | `andrewkrug@gmail.com`                                     |
| Sign-In required     | **No** — answer **No login required**                      |
| Demo Account         | _(leave blank)_                                            |

### Review Notes (paste verbatim)

```
Klck is a standalone metronome and chromatic tuner. No account, no network
calls, no third-party services.

To exercise the tuner, open the Tuner panel and tap LISTEN. macOS will
prompt for microphone access on first use; pitch detection runs entirely
on-device via autocorrelation. Audio is analyzed for fundamental frequency
and discarded — never recorded, never transmitted.

Sandbox entitlements requested:
- com.apple.security.app-sandbox (required for Mac App Store)
- com.apple.security.device.audio-input (for the chromatic tuner)

No additional permissions. No file access outside the app container.
Presets and setlists are persisted as small JSON files in
~/Library/Containers/com.klck.metronome/Data/Library/Application Support/Klck/.
```

### Attachment

Not required. (Apple sometimes asks for a demo video of permission-gated
features; if review asks, screen-record the tuner panel with LISTEN active
and attach via reply to their message.)

---

## Submission checklist

- [ ] Universal Purchase enabled on the iOS record (or accept that macOS is a
      separate listing).
- [ ] `Klck.pkg` uploaded via Transporter and showing in **TestFlight → Mac
      Builds** as `1.0 (1)`.
- [ ] Build attached to the macOS version page.
- [ ] All four App Information fields filled (categories, age rating, content
      rights answered).
- [ ] Pricing set to **USD 1.99**.
- [ ] Privacy Policy URL pasted and resolves (HTTPS, custom domain — not the
      github.io alias).
- [ ] App Privacy questionnaire answered "Data Not Collected" for every
      data type.
- [ ] Screenshot uploaded.
- [ ] Description, promotional text, keywords, copyright filled.
- [ ] Review Information notes pasted.
- [ ] "Submit for Review" clicked.
