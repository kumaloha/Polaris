# Character Assets

Flat character art used by the Godot UI.

- `*.png`: one square character illustration per playable character.
- `characters.json`: stable manifest for code. Paths are repo-relative `resources/characters/...` entries.

To rebuild the manifest after adding or removing PNG files:

```sh
/Users/kuma/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  godot/tools/build_character_manifest.py
```
