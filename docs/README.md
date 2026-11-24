# Ashen Realms

Dark fantasy, top-down pixel-art Action RPG for 2–4 players over LAN.

## Project setup

- Godot 4.7.2, GDScript, Forward+ renderer
- Base viewport: 640 × 360; initial window: 1280 × 720
- Canvas stretch mode with expanded aspect ratio
- Nearest-neighbor texture filtering
- Player characters save locally; world progress belongs to the host

## Structure

- `assets/` — visual and audio assets
- `scenes/` — Godot scenes
- `scripts/` — gameplay logic
- `resources/` — reusable game data
- `autoload/` — global managers
- `docs/` — project notes

Runtime saves belong in Godot's `user://` directory, not in this project folder.