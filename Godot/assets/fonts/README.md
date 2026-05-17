# Fonts

Both fonts below are licensed under the **SIL Open Font License 1.1 (OFL)**.

## ui_sans.ttf — body sans

- **Family:** Inter (variable TTF)
- **Source URL:** https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf
- **License:** SIL Open Font License 1.1 — https://github.com/google/fonts/blob/main/ofl/inter/OFL.txt
- **Fetched:** yes (876,576 bytes)

## ui_display.ttf — display serif

- **Family:** Cormorant (variable TTF)
- **Source URL:** https://github.com/google/fonts/raw/main/ofl/cormorant/Cormorant%5Bwght%5D.ttf
- **License:** SIL Open Font License 1.1 — https://github.com/google/fonts/blob/main/ofl/cormorant/OFL.txt
- **Fetched:** yes (572,892 bytes)

## Fallback behavior

`Godot/ui/UiKit.gd` guards both paths with `ResourceLoader.exists(...)` before
loading. If either TTF is missing, the engine-default font is used and the UI
still renders gracefully (no hard dependency on these assets).
