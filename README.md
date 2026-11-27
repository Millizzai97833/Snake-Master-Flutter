# Snake Master

Classic arcade Snake game built with Flutter.

## Features

- 18×24 grid playfield with progressive speed scaling (`max(75, 175 - score * 2)` ms)
- Score and Best Score tracking
- Swipe gestures, on-screen D-pad controls, and keyboard navigation (`Arrow` keys / `WASD`, `Space` to start/pause)
- Pause, resume, new game, and rewarded-revive support (Yandex Mobile Ads on mobile)
- Custom game launcher icon configured for web/PWA (`web/icons/`, `web/manifest.json`) and bundled at `assets/icon/app_icon.png`
