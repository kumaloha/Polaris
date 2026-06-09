# Magic Match Art Assets v1

Generated PNG asset pack for the match-3 magic/cube-pet theme.

## Important usage notes

- All assets are PNG with transparent backgrounds.
- Most VFX assets are white/gray and are intended to be tinted in Godot with `modulate` or shader color parameters.
- Ordinary pieces use a shape shadow generated from the current gem texture, so no separate shadow PNG is required.
- 4-match specials use body motion plus shader highlights instead of static overlay PNGs.
- The 5-match crystal ball uses the runtime single-image art `res://assets/level/diamond_white.png`; the older layered `special_5` runtime PNGs are no longer required.
- The original generated movement, reward, and transform VFX PNGs were removed because no runtime path loads them.

## Current Godot layering for the 5-match crystal ball

```text
ColorCorePiece.tscn
└── CoreBall            res://assets/level/diamond_white.png
```

## Suggested import settings

- Filter: on for soft VFX; test off/on for pixel crispness on gem icons.
- Mipmaps: off for UI-scale 2D unless you zoom the board.
- Repeat: disabled.
- Use each VFX as a Sprite2D/GPUParticles2D texture and tint in Godot.
