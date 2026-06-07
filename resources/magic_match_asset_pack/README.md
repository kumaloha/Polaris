# Magic Match Art Assets v1

Generated PNG asset pack for the match-3 magic/cube-pet theme.

## Important usage notes

- All assets are PNG with transparent backgrounds.
- Most VFX assets are white/gray and are intended to be tinted in Godot with `modulate` or shader color parameters.
- Ordinary pieces use `art/gems/base/gem_shadow_soft.png` as their soft contact shadow.
- The 5-match crystal ball does **not** use the ordinary shadow. It uses `art/gems/special_5/special_5_gold_ground_glow.png` as its separate golden magic floor glow.
- The 5-match ball is split into layers so Godot can animate them independently:
  - `special_5_core_ball.png`
  - `special_5_gold_ground_glow.png`
  - `special_5_cube_ring.png`
  - `special_5_inner_swirl.png`
  - `special_5_inner_stars.png`

## Suggested Godot layering for the 5-match crystal ball

```text
ColorCorePiece.tscn
├── GroundGoldGlow      special_5_gold_ground_glow.png
├── CoreBall            special_5_core_ball.png
├── InnerSwirl          special_5_inner_swirl.png
├── InnerStars          special_5_inner_stars.png
└── CubeRing            special_5_cube_ring.png
```

## Suggested import settings

- Filter: on for soft VFX; test off/on for pixel crispness on gem icons.
- Mipmaps: off for UI-scale 2D unless you zoom the board.
- Repeat: disabled.
- Use each VFX as a Sprite2D/GPUParticles2D texture and tint in Godot.

