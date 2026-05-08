# Metronome

A minimal, dark-themed metronome app built with Flutter.

## Features

**Core**
- BPM range 40 – 220, adjustable via slider, ±1/±5 step buttons, or direct input
- Italian tempo labels (Largo → Prestissimo)
- Time signatures: 4/4, 3/4, 6/8 with automatic accent detection
- Tap tempo — tap repeatedly to set BPM by feel
- Screen stays on while the metronome is running

**BPM Mode**
- **Standard** — BPM = clicks per minute, independent of time signature
- **DAW** — BPM always refers to quarter notes; 6/8 at BPM 120 plays twice as fast as 4/4

**Progressive Mode**
- Gradually increases or decreases BPM from a start value to an end value
- Configurable bars-per-step (1 / 2 / 4 / 8)
- Live progress bar shows current position in the ramp

**Mic Monitor**
- Listens via microphone and detects note onsets
- Flashes red when your playing is more than ~150 ms off the beat

## Getting Started

**Requirements:** Flutter 3.x, Dart SDK ≥ 3.11

```bash
flutter pub get
flutter run
```

## Tech Stack

| Layer | Choice |
|---|---|
| UI framework | Flutter |
| State management | Provider |
| Audio playback | audioplayers |
| Mic / recording | record |
| Screen wake lock | wakelock_plus |
| Permissions | permission_handler |

## Project Structure

```
lib/
├── main.dart                       # App entry, theme, orientation lock
├── controllers/
│   └── metronome_controller.dart   # All state & scheduling logic
├── models/
│   └── time_signature.dart         # Time signature definitions
├── screens/
│   └── home_screen.dart            # UI
└── services/
    ├── audio_service.dart          # Tick sound playback
    └── beat_detector.dart          # Microphone onset detection
```

## License

MIT
