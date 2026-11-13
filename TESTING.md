# Verification

Version 1.0.3 was tested with Factorio 2.1.24 and Space Age.

- Upgrading a world from 1.0.2 replaces the old panel and retains the heat estimate.
- The toolbar button, close button and per-player setting control window visibility. Two players keep independent visibility and fuel choices.
- Coal, wood, rocket fuel, nuclear fuel and a compatible modded fuel produce the expected consumption estimates. Incompatible fuels are rejected; clearing the selector removes the fuel estimate.
- Changing the viewed surface or force updates the panel. The panel stays hidden on planets that do not require heating.
- Saving and reloading preserves selected fuel, a cleared selector and hidden-window preferences.
- A real multiplayer client joined, ran through synchronized ticks, then rejoined after the host saved and reloaded. Player choices were retained without a desync.
- The panel, buttons, selected fuel and consumption estimate were checked in the rendered game at 1280 × 720.

Tests used an isolated Linux server and an offscreen client. Refreshing is event-driven; the mod has no per-tick entity scan.
